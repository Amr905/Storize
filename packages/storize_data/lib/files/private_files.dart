import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// What a copy must match: the source's size and, when known, its sha256
/// (lower-case hex).
final class CopyCheck {
  /// Creates a check. A null part is not compared.
  const CopyCheck({this.size, this.sha256});

  /// The expected size in bytes.
  final int? size;

  /// The expected sha256, lower-case hex.
  final String? sha256;
}

/// Storize's private media storage (FR-79): files that only Storize shows.
///
/// They live under `<external files dir>/Pictures/Storize/<dir>/` (Android's
/// app-specific external storage). MediaStore does not scan that folder, a
/// `.nomedia` file at its root asks other scanners to skip it too, and
/// uninstalling the app deletes it. A file is addressed by a `file://` URI;
/// [storageTargetOf] tells it from a gallery `content://` URI.
///
/// **Safety.** A write goes to a hidden temporary file in the final folder,
/// is verified and then renamed into place, so a reader never sees a half
/// file and a failure leaves nothing behind. Every operation on an existing
/// file first checks the URI is inside the Storize folder, so a damaged row
/// can never make the app touch another file. Errors carry codes only, never
/// paths.
final class PrivateFiles {
  /// Creates the storage. `pictures` gives the app-specific `Pictures`
  /// directory (tests pass a temp directory).
  PrivateFiles({required this._pictures});

  /// The production storage: `getExternalFilesDir(DIRECTORY_PICTURES)`.
  PrivateFiles.pathProvider() : this(pictures: _externalPictures);

  final Future<Directory> Function() _pictures;

  /// The largest file whose content hash is compared when copying (50 MB).
  static const int hashLimitBytes = 50 * 1024 * 1024;

  /// The folder under `Pictures` that holds everything.
  static const String folder = 'Storize';

  static const String _nomedia = '.nomedia';
  static final Random _random = Random.secure();

  static Future<Directory> _externalPictures() async {
    final dirs = await getExternalStorageDirectories(
      type: StorageDirectory.pictures,
    );
    if (dirs == null || dirs.isEmpty) {
      throw const GalleryWriteFailed('PRIVATE_UNAVAILABLE');
    }
    return dirs.first;
  }

  /// The Storize folder, created (with its `.nomedia`) when missing.
  Future<Directory> root() async {
    final Directory dir;
    try {
      dir = Directory('${(await _pictures()).path}/$folder');
      await dir.create(recursive: true);
      final marker = File('${dir.path}/$_nomedia');
      if (!marker.existsSync()) await marker.writeAsBytes(const []);
    } on GalleryStoreException {
      rethrow;
    } on FileSystemException catch (e) {
      throw _map(e);
    }
    return dir;
  }

  /// The local path of [uri] when it is a `file://` URI inside the Storize
  /// folder, else null. Dots and encoded separators cannot escape it.
  Future<String?> pathOf(String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.scheme != 'file') return null;
    // `toFilePath` refuses these, and none of them is a path we wrote.
    if (parsed.hasQuery || parsed.hasFragment || parsed.host.isNotEmpty) {
      return null;
    }
    final path = parsed.normalizePath().toFilePath();
    // Symlinks are resolved on both sides before the inside-root check, so a
    // linked folder or file cannot lead outside. Any error refuses.
    try {
      final root = Directory(
        '${(await _pictures()).path}/$folder',
      ).resolveSymbolicLinksSync();
      final file = File(path);
      final resolved = file.existsSync()
          ? file.resolveSymbolicLinksSync()
          : '${file.parent.resolveSymbolicLinksSync()}/'
                '${file.uri.pathSegments.last}';
      final prefix = root.endsWith('/') ? root : '$root/';
      return resolved.startsWith(prefix) && resolved.length > prefix.length
          ? resolved
          : null;
    } on FileSystemException {
      return null;
    }
  }

  /// Whether the file at [uri] exists. An address outside the folder is
  /// "missing".
  Future<bool> exists(String uri) async {
    final path = await pathOf(uri);
    return path != null && File(path).existsSync();
  }

  /// The size of the file at [uri], or null when it is missing.
  Future<int?> size(String uri) async {
    final path = await pathOf(uri);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file.lengthSync() : null;
  }

  /// Deletes the file at [uri]. False when it was already gone (or the
  /// address is not ours).
  Future<bool> delete(String uri) async {
    final path = await pathOf(uri);
    if (path == null) return false;
    final file = File(path);
    if (!file.existsSync()) return false;
    try {
      await file.delete();
      return true;
    } on FileSystemException catch (e) {
      throw _map(e);
    }
  }

  /// The bytes of the file at [uri], or null when it is missing or longer than
  /// [maxBytes].
  Future<Uint8List?> readBytes(String uri, {int maxBytes = 30 << 20}) async {
    final path = await pathOf(uri);
    if (path == null) return null;
    final file = File(path);
    try {
      if (!file.existsSync() || file.lengthSync() > maxBytes) return null;
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  /// Copies [sourcePath] into private storage. See [writeNew].
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const GalleryWriteFailed('SOURCE_NOT_FOUND');
    }
    return writeNew(
      relativeDir: relativeDir,
      displayName: displayName,
      fill: (tmp) async {
        await source.copy(tmp.path);
        return CopyCheck(size: source.lengthSync());
      },
    );
  }

  /// Creates a new private file `<relativeDir>/<displayName>` whose content
  /// [fill] writes into the temporary file it is given. [fill] returns what
  /// the source looked like (a [CopyCheck]).
  ///
  /// The result is checked against it (the hash only up to [hashLimitBytes])
  /// and then renamed into place. A name
  /// that is taken becomes `name (1).ext`. On any failure the temporary file
  /// is removed and an exception is thrown: [GalleryStorageFull] for a full
  /// disk, [GalleryWriteFailed] (`VERIFY_FAILED` for a bad copy) otherwise.
  Future<GalleryFile> writeNew({
    required String relativeDir,
    required String displayName,
    required Future<CopyCheck> Function(File tmp) fill,
  }) async {
    final dirParts = _checkedSegments(relativeDir);
    final name = _checkedName(displayName);
    final base = await root();
    final dir = Directory('${base.path}/${dirParts.join('/')}');
    final tmp = File(
      '${dir.path}/.$name.${_random.nextInt(1 << 32).toRadixString(16)}.part',
    );
    try {
      await dir.create(recursive: true);
      final check = await fill(tmp);
      final written = await tmp.length();
      if (check.size != null && written != check.size) {
        throw const GalleryWriteFailed('VERIFY_FAILED');
      }
      if (check.sha256 != null && written <= hashLimitBytes) {
        if (await sha256Of(tmp) != check.sha256) {
          throw const GalleryWriteFailed('VERIFY_FAILED');
        }
      }
      final finalName = _freeName(dir, name);
      final target = await tmp.rename('${dir.path}/$finalName');
      return GalleryFile(
        uri: Uri.file(target.path).toString(),
        sizeBytes: written,
        relativePath: 'Pictures/$folder/${dirParts.join('/')}/',
        displayName: finalName,
      );
    } on GalleryStoreException {
      await _discard(tmp);
      rethrow;
    } on FileSystemException catch (e) {
      await _discard(tmp);
      throw _map(e);
    } on Object {
      await _discard(tmp);
      rethrow;
    }
  }

  /// [bytes] as lower-case hex.
  static String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// The sha256 of the file at [file], as lower-case hex, streamed.
  static Future<String> sha256Of(File file) async {
    final sink = const DartSha256().newHashSink();
    await file.openRead().forEach(sink.add);
    sink.close();
    return hex((await sink.hash()).bytes);
  }

  /// The sha256 of [bytes], as lower-case hex.
  static String sha256OfBytes(List<int> bytes) =>
      hex(const DartSha256().hashSync(bytes).bytes);

  static String _freeName(Directory dir, String name) {
    if (!File('${dir.path}/$name').existsSync()) return name;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var i = 1; ; i++) {
      final candidate = '$stem ($i)$ext';
      if (!File('${dir.path}/$candidate').existsSync()) return candidate;
    }
  }

  static Future<void> _discard(File tmp) async {
    try {
      if (tmp.existsSync()) await tmp.delete();
    } on Object {
      // Best effort: a stray hidden temp file is harmless.
    }
  }

  /// `a/b/c` as safe segments: no empty, `.` or `..` parts, no separators
  /// other than `/`, no control characters.
  static List<String> _checkedSegments(String relativeDir) {
    final parts = relativeDir.split('/');
    for (final p in parts) {
      if (p.isEmpty ||
          p == '.' ||
          p == '..' ||
          p.contains(r'\') ||
          p.codeUnits.any((c) => c < 0x20 || c == 0x7f)) {
        throw const GalleryWriteFailed('INVALID_ARGUMENT');
      }
    }
    return parts;
  }

  static String _checkedName(String name) {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains(r'\') ||
        name.codeUnits.any((c) => c < 0x20 || c == 0x7f)) {
      throw const GalleryWriteFailed('INVALID_ARGUMENT');
    }
    return name;
  }

  /// A full disk is `ENOSPC` (28); anything else is a write failure with a
  /// fixed code (the message may hold a path, so it is dropped).
  static GalleryStoreException _map(FileSystemException e) =>
      e.osError?.errorCode == 28
      ? const GalleryStorageFull()
      : const GalleryWriteFailed('IO_ERROR');
}
