// Test-only: lint noise from dense adversarial inputs is suppressed on purpose.
// ignore_for_file: cascade_invocations, lines_longer_than_80_chars, unnecessary_lambdas
// QA (T-011): rotation, resilience and log-forging tests.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/file_diagnostic_log.dart';
import 'package:storize_data/log/rotating_log_file.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('storize_qa_rot_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  List<String> names(Directory d) => d.existsSync()
      ? (d.listSync().map((e) => e.path.split('/').last).toList()..sort())
      : [];

  test('default limits are 3 files x 1 MB', () {
    final f = RotatingLogFile(Directory('${tmp.path}/l'));
    expect(f.maxFiles, 3);
    expect(f.maxBytes, 1024 * 1024);
  });

  test(
    'real 1 MB cap: 5 MB of lines, never more than 3 files, each <= 1 MB',
    () {
      final dir = Directory('${tmp.path}/l');
      final f = RotatingLogFile(dir);
      final line = 'x' * 999; // 1000 bytes with newline
      for (var i = 0; i < 5000; i++) {
        f.append(line);
      }
      expect(names(dir), ['storize.log', 'storize.log.1', 'storize.log.2']);
      for (final file in f.files) {
        expect(file.lengthSync(), lessThanOrEqualTo(1024 * 1024));
      }
    },
  );

  test('newest data survives; oldest is dropped', () {
    final dir = Directory('${tmp.path}/l');
    final f = RotatingLogFile(dir, maxBytes: 100);
    for (var i = 0; i < 100; i++) {
      f.append('line-${i.toString().padLeft(3, '0')}-${'y' * 20}');
    }
    final all = f.files.reversed.expand((x) => x.readAsLinesSync()).toList();
    expect(all.last, startsWith('line-099'));
    expect(all.first, isNot(startsWith('line-000')));
    // No gaps inside the retained window.
    final nums = all.map((l) => int.parse(l.substring(5, 8))).toList();
    for (var i = 1; i < nums.length; i++) {
      expect(nums[i], nums[i - 1] + 1);
    }
  });

  test(
    'a single line larger than 1 MB is cut, file stays <= 1 MB, no throw',
    () {
      final dir = Directory('${tmp.path}/l');
      final f = RotatingLogFile(dir);
      f.append('a' * (3 * 1024 * 1024));
      f.append('after');
      for (final file in f.files) {
        expect(file.lengthSync(), lessThanOrEqualTo(1024 * 1024));
      }
      expect(f.files.length, lessThanOrEqualTo(3));
      expect(f.current.readAsStringSync(), contains('after'));
    },
  );

  test('multi-byte line larger than the cap is cut without throwing', () {
    final f = RotatingLogFile(Directory('${tmp.path}/l'), maxBytes: 1000);
    f.append('é' * 5000); // 2 bytes each; the cut may split a character
    expect(f.current.lengthSync(), lessThanOrEqualTo(1000));
    // The cut can leave a broken UTF-8 tail; reading must be possible lossy.
    expect(
      () => utf8.decode(f.current.readAsBytesSync(), allowMalformed: true),
      returnsNormally,
    );
  });

  test('crash mid-rotation (log.1 renamed, no current file) recovers', () {
    final dir = Directory('${tmp.path}/l')..createSync();
    File('${dir.path}/storize.log.1').writeAsStringSync('old1\n');
    File('${dir.path}/storize.log.2').writeAsStringSync('old2\n');
    final f = RotatingLogFile(dir, maxBytes: 50);
    f.append('new');
    expect(f.current.readAsStringSync(), 'new\n');
    for (var i = 0; i < 20; i++) {
      f.append('fill-fill-fill-fill-$i');
    }
    expect(names(dir).length, lessThanOrEqualTo(3));
  });

  test('crash mid-rotation (middle file missing) recovers', () {
    final dir = Directory('${tmp.path}/l')..createSync();
    File('${dir.path}/storize.log').writeAsStringSync('${'z' * 48}\n');
    File('${dir.path}/storize.log.2').writeAsStringSync('old2\n');
    final f = RotatingLogFile(dir, maxBytes: 50);
    f.append('next-line');
    expect(names(dir).length, lessThanOrEqualTo(3));
    expect(f.current.readAsStringSync(), contains('next-line'));
  });

  test('stray extra files (storize.log.3, .7) are deleted (F9)', () {
    final dir = Directory('${tmp.path}/l')..createSync();
    File('${dir.path}/storize.log.3').writeAsStringSync('stray\n');
    File('${dir.path}/storize.log.7').writeAsStringSync('stray\n');
    File('${dir.path}/other.log.9').writeAsStringSync('not ours\n');
    final f = RotatingLogFile(dir, maxBytes: 50);
    for (var i = 0; i < 30; i++) {
      f.append('filling-line-number-$i');
    }
    expect(f.files.length, 3);
    expect(File('${dir.path}/storize.log.3').existsSync(), isFalse);
    expect(File('${dir.path}/storize.log.7').existsSync(), isFalse);
    expect(File('${dir.path}/other.log.9').existsSync(), isTrue);
  });

  test('append never throws when the directory is deleted between writes', () {
    final dir = Directory('${tmp.path}/l');
    final f = RotatingLogFile(dir);
    f.append('one');
    dir.deleteSync(recursive: true);
    expect(() => f.append('two'), returnsNormally);
    expect(f.current.readAsStringSync(), 'two\n'); // recreated
  });

  test('append never throws when the log path is blocked by a file', () {
    final blocker = File('${tmp.path}/l')..writeAsStringSync('i am a file');
    final f = RotatingLogFile(Directory(blocker.path));
    expect(() => f.append('x'), returnsNormally);
    expect(() => f.clear(), returnsNormally);
    expect(f.files, isEmpty);
  });

  test('append never throws when the current log is a directory', () {
    final dir = Directory('${tmp.path}/l')..createSync();
    Directory('${dir.path}/storize.log').createSync();
    final f = RotatingLogFile(dir);
    expect(() => f.append('x'), returnsNormally);
  });

  test('read-only directory (full-disk stand-in) never throws', () {
    if (Platform.isWindows) return;
    final dir = Directory('${tmp.path}/l')..createSync();
    Process.runSync('chmod', ['555', dir.path]);
    addTearDown(() => Process.runSync('chmod', ['755', dir.path]));
    final f = RotatingLogFile(dir);
    expect(() => f.append('x'), returnsNormally);
  });

  test('/dev/full (ENOSPC) never throws', () {
    if (!File('/dev/full').existsSync()) return;
    final dir = Directory('${tmp.path}/l')..createSync();
    Link('${dir.path}/storize.log').createSync('/dev/full');
    final f = RotatingLogFile(dir);
    expect(() => f.append('x'), returnsNormally);
  });

  test(
    'FileDiagnosticLog.log never throws on a broken sink or hostile error',
    () {
      final blocker = File('${tmp.path}/l')..writeAsStringSync('f');
      final log = FileDiagnosticLog(
        file: RotatingLogFile(Directory(blocker.path)),
        clock: FakeClock(DateTime.utc(2026)),
        console: true,
        consoleSink: (_) => throw StateError('console broke'),
      );
      expect(
        () => log.log(
          LogLevel.error,
          't',
          'm',
          error: _Hostile(),
          stack: StackTrace.current,
        ),
        returnsNormally,
      );
    },
  );

  test(
    'concurrent appends from 4 isolates: cap holds, nothing throws',
    () async {
      final dir = Directory('${tmp.path}/l')..createSync();
      final results = await Future.wait([
        for (var i = 0; i < 4; i++) Isolate.run(() => _spam(dir.path, i)),
      ]);
      expect(results, everyElement('ok'));
      final f = RotatingLogFile(dir, maxBytes: 20000);
      expect(f.files.length, lessThanOrEqualTo(3));
      final extra = names(dir)
          .where((n) => !n.startsWith('storize.log'))
          .toList();
      expect(extra, isEmpty);
      for (final file in f.files) {
        // Cross-isolate rotation is best effort (documented): allow one line of slack per isolate.
        expect(file.lengthSync(), lessThanOrEqualTo(20000 + 4 * 200));
      }
    },
  );

  group('log forging (newline injection)', () {
    late FileDiagnosticLog log;
    late RotatingLogFile file;
    setUp(() {
      file = RotatingLogFile(Directory('${tmp.path}/l'));
      log = FileDiagnosticLog(
        file: file,
        clock: FakeClock(DateTime.utc(2026, 11, 19)),
      );
    });

    test('tag cannot inject lines', () {
      log.log(LogLevel.info, 'a\nb', 'm');
      expect(file.current.readAsLinesSync().length, 1);
    });

    test('message newline cannot forge a whole log line (F2)', () {
      log.log(
        LogLevel.info,
        'net',
        'status 200\n2026-11-19T00:00:00.000Z ERROR [crash] forged',
      );
      final lines = file.current.readAsLinesSync();
      expect(
        lines.where((l) => l.startsWith('2026-')).length,
        1,
        reason: 'forged line starts at column 0: $lines',
      );
    });
  });
}

class _Hostile {
  @override
  String toString() => throw StateError('toString broke');
}

String _spam(String path, int id) {
  final f = RotatingLogFile(Directory(path), maxBytes: 20000);
  for (var i = 0; i < 1500; i++) {
    f.append('iso$id line $i ${'p' * 100}');
  }
  return 'ok';
}
