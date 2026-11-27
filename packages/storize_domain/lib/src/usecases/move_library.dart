import 'package:storize_domain/src/entities/content_filter.dart';
import 'package:storize_domain/src/entities/governor_lease.dart';
import 'package:storize_domain/src/entities/media_file.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/diagnostic_log.dart';
import 'package:storize_domain/src/ports/gallery_store.dart';
import 'package:storize_domain/src/ports/move_state_store.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/governor_lease_repo.dart';
import 'package:storize_model/storize_model.dart';

/// How a [MoveLibrary.run] ended.
enum MoveEnd {
  /// Every file was handled.
  finished,

  /// The user cancelled.
  cancelled,

  /// The device is out of space.
  storageFull,

  /// The time budget ran out with files left: queue the task again.
  deadline,

  /// Another run holds the move lease (another isolate). Nothing was done.
  busy,
}

/// The outcome of one [MoveLibrary.run].
final class MoveLibraryResult {
  /// Creates a result.
  const MoveLibraryResult({required this.end, required this.progress});

  /// Why the run stopped.
  final MoveEnd end;

  /// The final progress.
  final MoveProgress progress;

  @override
  String toString() => 'MoveLibraryResult(${end.name}, $progress)';
}

/// Moves every saved file between the phone gallery and private storage
/// (FR-79).
///
/// **Safety.** For each file: `GalleryStore.copyTo` copies and verifies (the
/// original is untouched), then the row is updated to the new reference, and
/// only then the original is deleted. A crash at any point leaves either the
/// old reference valid (original intact; at worst a stray extra copy) or the
/// new one valid (at worst a leftover original). Nothing is ever lost.
///
/// **Resumable, never twice.** The reference of a row says where its file is
/// ([storageTargetOf]); rows already at the target are skipped, so a run that
/// was interrupted simply continues and a second run does nothing.
///
/// A file whose original is gone is counted as `missing` (not a failure). A
/// full device stops the run cleanly. Other per-file failures are counted and
/// the file stays where it was. The log gets counts and codes only: never
/// paths, usernames or URIs.
final class MoveLibrary {
  /// Creates the use case. Files are handled in batches of [batchSize]; the
  /// cancel request is checked before every file.
  MoveLibrary({
    required this._content,
    required this._gallery,
    required this._state,
    required this._clock,
    required this._leases,
    this._log,
    this.batchSize = 20,
    String? holder,
  }) : _holder =
           holder ?? 'move-${_clock.now().microsecondsSinceEpoch}-${_seq++}';

  static int _seq = 0;

  /// The key of the move lease in the lease table (login uses -1, downloads
  /// -2). One move runs at a time across isolates.
  static const int leaseKey = -3;

  /// How long a lease holds without renewal: a crashed run frees it after
  /// this (the run renews before every file).
  static const Duration leaseTtl = Duration(minutes: 10);

  final ContentRepo _content;
  final GalleryStore _gallery;
  final MoveStateStore _state;
  final Clock _clock;
  final GovernorLeaseRepo _leases;
  final String _holder;
  final DiagnosticLog? _log;

  /// How many files are loaded and handled per batch.
  final int batchSize;

  /// How many saved files are not yet at [target] (for "Move N saved files
  /// now?").
  Future<int> countToMove(StorageTarget target) async =>
      (await _pending(target)).length;

  /// Asks the running move to stop after the file it is working on. The state
  /// shows `cancelled` at once.
  Future<void> cancel() async {
    await _state.setCancelRequested(value: true);
    final p = await _state.read();
    if (p.status == MoveStatus.running) {
      await _state.write(
        p.copyWith(status: MoveStatus.cancelled, updatedAt: _clock.now()),
      );
    }
  }

  /// Moves the saved files to [target] until done, cancelled, out of space or
  /// past [deadline]. Never throws for per-file failures.
  ///
  /// [onProgress] is called after every written progress (for a notification).
  Future<MoveLibraryResult> run(
    StorageTarget target, {
    DateTime? deadline,
    void Function(MoveProgress progress)? onProgress,
  }) async {
    final lease = await _leases.acquire(
      accountId: leaseKey,
      holder: _holder,
      ttl: leaseTtl,
      initialBucket: GovernorBucket(tokens: 0, lastRefillAt: _clock.now()),
    );
    if (lease == null) {
      _log?.log(LogLevel.info, 'move', 'end=busy');
      return MoveLibraryResult(
        end: MoveEnd.busy,
        progress: await _state.read(),
      );
    }
    try {
      return await _runLeased(target, deadline, onProgress);
    } finally {
      await _leases.release(accountId: leaseKey, holder: _holder);
    }
  }

  Future<MoveLibraryResult> _runLeased(
    StorageTarget target,
    DateTime? deadline,
    void Function(MoveProgress progress)? onProgress,
  ) async {
    await _state.setCancelRequested(value: false);
    final before = await _state.read();
    final resuming =
        before.target == target &&
        before.status != MoveStatus.idle &&
        (before.status != MoveStatus.done || before.failed > 0);
    var moved = resuming ? before.moved : 0;
    var missing = resuming ? before.missing : 0;
    var failed = 0;

    final todo = await _pending(target);
    final total = moved + missing + todo.length;

    Future<MoveProgress> publish(MoveStatus status) async {
      final p = MoveProgress(
        status: status,
        target: target,
        total: total,
        moved: moved,
        missing: missing,
        failed: failed,
        updatedAt: _clock.now(),
      );
      await _state.write(p);
      onProgress?.call(p);
      return p;
    }

    MoveLibraryResult stop(MoveEnd end, MoveProgress p) {
      _log?.log(
        LogLevel.info,
        'move',
        'end=${end.name} target=${target.name} moved=${p.moved} '
            'missing=${p.missing} failed=${p.failed} total=${p.total}',
      );
      return MoveLibraryResult(end: end, progress: p);
    }

    await publish(MoveStatus.running);
    for (var i = 0; i < todo.length; i += batchSize) {
      final batch = todo.skip(i).take(batchSize);
      for (final item in batch) {
        if (await _state.cancelRequested()) {
          await _state.setCancelRequested(value: false);
          return stop(MoveEnd.cancelled, await publish(MoveStatus.cancelled));
        }
        if (deadline != null && !_clock.now().isBefore(deadline)) {
          return stop(MoveEnd.deadline, await publish(MoveStatus.running));
        }
        // Still ours? A lost lease (stale for 10 minutes) ends the run: the
        // other runner owns the files now.
        if (!await _leases.renew(
          accountId: leaseKey,
          holder: _holder,
          ttl: leaseTtl,
        )) {
          return stop(MoveEnd.deadline, await publish(MoveStatus.running));
        }
        final outcome = await _moveOne(item, target);
        switch (outcome) {
          case _Outcome.moved:
            moved += 1;
          case _Outcome.missing:
            missing += 1;
          case _Outcome.failed:
            failed += 1;
          case _Outcome.gone:
            // The user deleted the item meanwhile: nothing to move.
            break;
          case _Outcome.full:
            return stop(
              MoveEnd.storageFull,
              await publish(MoveStatus.storageFull),
            );
        }
        await publish(MoveStatus.running);
      }
    }
    return stop(MoveEnd.finished, await publish(MoveStatus.done));
  }

  /// Every finished file whose reference is not at [target].
  Future<List<MediaFile>> _pending(StorageTarget target) async {
    final all = await _content.watchLibrary(ContentFilter()).first;
    return [
      for (final c in all)
        for (final m in c.media)
          if (m.status == MediaFileStatus.done &&
              m.contentUri != null &&
              storageTargetOf(m.contentUri!) != target)
            m,
    ];
  }

  Future<_Outcome> _moveOne(MediaFile row, StorageTarget target) async {
    final original = row.contentUri!;
    final dir = relativeDirOf(row.relativePath);
    final name = row.displayName;
    if (dir == null || name == null) {
      _log?.log(LogLevel.warn, 'move', 'file_failed code=NO_PATH');
      return _Outcome.failed;
    }
    final GalleryFile copy;
    try {
      // 1. Copy and verify. The original is untouched.
      copy = await _gallery.copyTo(
        original,
        to: target,
        relativeDir: dir,
        displayName: name,
        mime: row.mediaType == MediaType.photo ? 'image/jpeg' : 'video/mp4',
      );
    } on GalleryStorageFull {
      return _Outcome.full;
    } on GalleryStoreException catch (e) {
      if (e.code == 'SOURCE_NOT_FOUND') return _Outcome.missing;
      _log?.log(LogLevel.warn, 'move', 'file_failed code=${e.code}');
      return _Outcome.failed;
    } on Exception {
      // Only the type is known here; it can carry a path, so it is not logged.
      _log?.log(LogLevel.warn, 'move', 'file_failed code=UNEXPECTED');
      return _Outcome.failed;
    }
    // 2. The row follows the verified copy, but only if it still holds the
    // original (compare-and-set): a concurrent mover or a delete wins, and
    // then our copy is dropped.
    try {
      final updated = await _content.updateMediaFileIfUri(
        row.copyWith(
          contentUri: copy.uri,
          relativePath: copy.relativePath,
          displayName: copy.displayName,
          sizeBytes: copy.sizeBytes,
        ),
        expectedContentUri: original,
      );
      if (!updated) {
        await _dropCopy(copy.uri);
        return _Outcome.gone;
      }
    } on Object {
      await _dropCopy(copy.uri);
      _log?.log(LogLevel.warn, 'move', 'file_failed code=ROW_UPDATE');
      return _Outcome.failed;
    }
    // 3. Only now is the original disposable. A failure keeps it: a leftover
    // duplicate is safer than a lost file.
    try {
      await _gallery.delete(original);
    } on GalleryStoreException catch (e) {
      _log?.log(LogLevel.warn, 'move', 'original_kept code=${e.code}');
    }
    return _Outcome.moved;
  }

  Future<void> _dropCopy(String uri) async {
    try {
      await _gallery.delete(uri);
    } on Object {
      // Best effort: a stray copy is harmless.
    }
  }

  /// The folder part of a stored relative path: `Pictures/Storize/<dir>/`
  /// gives `<dir>`. Null when there is no `Storize/` folder in it.
  static String? relativeDirOf(String? relativePath) {
    if (relativePath == null) return null;
    const marker = 'Storize/';
    final at = relativePath.indexOf(marker);
    if (at < 0) return null;
    var dir = relativePath.substring(at + marker.length);
    while (dir.endsWith('/')) {
      dir = dir.substring(0, dir.length - 1);
    }
    return dir.isEmpty ? null : dir;
  }
}

enum _Outcome { moved, missing, failed, gone, full }
