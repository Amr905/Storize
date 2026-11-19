import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// A size-capped, rotating text file: `storize.log`, `storize.log.1`,
/// `storize.log.2` (newest to oldest), at most [maxFiles] files of at most
/// [maxBytes] each (TECH_SPEC §8: 3 x 1 MB).
///
/// **Serialisation.** Every write is a short synchronous operation, so inside
/// one isolate writes cannot interleave or reorder (the Dart event loop is
/// single-threaded) and a line is on disk before [append] returns, which also
/// makes it survive a crash that follows immediately.
///
/// **Isolates.** The background dispatcher runs in its own isolate and may
/// write to the same files. That is best-effort: each append re-reads the
/// current file size, and appends of short lines are atomic enough on Android
/// in practice, but two isolates rotating at the same moment could drop or
/// mix a few lines. Nothing throws and no file is corrupted beyond that.
///
/// The class never writes anything itself except the lines it is given, so
/// callers must redact first (see `Redactor`).
final class RotatingLogFile {
  /// Creates a log in [directory] (created on first write).
  ///
  /// [maxBytes] is the size limit of one file and [maxFiles] how many files
  /// are kept, counting the current one.
  RotatingLogFile(
    this.directory, {
    this.baseName = 'storize.log',
    this.maxBytes = 1024 * 1024,
    this.maxFiles = 3,
  }) : assert(maxBytes > 0, 'maxBytes must be positive'),
       assert(maxFiles >= 1, 'maxFiles must be at least 1');

  /// The directory holding the files (the app support directory plus `logs`).
  final Directory directory;

  /// The name of the current file. Older ones get `.1`, `.2`, and so on.
  final String baseName;

  /// The most bytes one file may hold.
  final int maxBytes;

  /// The most files kept, including the current one.
  final int maxFiles;

  bool _strayChecked = false;

  /// The current (newest) file.
  File get current => File('${directory.path}/$baseName');

  /// All existing log files, newest first.
  List<File> get files => [
    for (var i = 0; i < maxFiles; i++)
      if (_file(i).existsSync()) _file(i),
  ];

  File _file(int index) =>
      index == 0 ? current : File('${directory.path}/$baseName.$index');

  /// Appends [line] and a newline. Rotates first when the line would push the
  /// current file over [maxBytes]. A line longer than [maxBytes] is cut to
  /// fit. Never throws: a failing disk must not break the app.
  void append(String line) {
    try {
      var bytes = utf8.encode('$line\n');
      if (bytes.length > maxBytes) {
        bytes = Uint8List.fromList([...bytes.sublist(0, maxBytes - 1), 0x0A]);
      }
      if (!directory.existsSync()) directory.createSync(recursive: true);
      if (!_strayChecked) {
        _strayChecked = true;
        _deleteStray();
      }
      final file = current;
      final size = file.existsSync() ? file.lengthSync() : 0;
      if (size > 0 && size + bytes.length > maxBytes) _rotate();
      current.writeAsBytesSync(bytes, mode: FileMode.append, flush: true);
    } on Object {
      // Logging must never throw.
    }
  }

  /// Deletes all log files.
  void clear() {
    for (var i = 0; i < math.max(maxFiles, 1); i++) {
      try {
        final f = _file(i);
        if (f.existsSync()) f.deleteSync();
      } on Object {
        // Best effort.
      }
    }
  }

  /// Deletes `<baseName>.N` files with N >= [maxFiles] (left by an older
  /// configuration), so the cap holds for everything in the directory.
  void _deleteStray() {
    try {
      final pattern = RegExp('^${RegExp.escape(baseName)}\\.(\\d+)\$');
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final m = pattern.firstMatch(name);
        if (m == null) continue;
        final index = int.tryParse(m[1]!);
        if (index == null || index >= maxFiles) {
          try {
            entity.deleteSync();
          } on Object {
            // Best effort.
          }
        }
      }
    } on Object {
      // Best effort.
    }
  }

  void _rotate() {
    _deleteStray();
    final last = _file(maxFiles - 1);
    if (last.existsSync()) last.deleteSync();
    for (var i = maxFiles - 2; i >= 0; i--) {
      final f = _file(i);
      if (f.existsSync()) f.renameSync(_file(i + 1).path);
    }
  }
}
