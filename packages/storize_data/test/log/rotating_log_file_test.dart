import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/rotating_log_file.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('storize_log_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  RotatingLogFile make({int maxBytes = 100, int maxFiles = 3}) =>
      RotatingLogFile(
        Directory('${tmp.path}/logs'),
        maxBytes: maxBytes,
        maxFiles: maxFiles,
      );

  test('defaults are 3 files of 1 MB', () {
    final log = RotatingLogFile(tmp);
    expect(log.maxBytes, 1024 * 1024);
    expect(log.maxFiles, 3);
    expect(log.baseName, 'storize.log');
  });

  test('creates the directory and appends lines in order', () {
    final log = make()
      ..append('one')
      ..append('two');
    expect(log.current.readAsStringSync(), 'one\ntwo\n');
    expect(log.files, hasLength(1));
  });

  test('rotates when the next line would exceed the limit', () {
    final log = make()
      ..append('a' * 59) // 60 bytes with the newline
      ..append('b' * 29); // 30 more = 90, fits
    expect(log.files, hasLength(1));
    log.append('c' * 29); // 120 > 100, so rotate first
    expect(log.files, hasLength(2));
    expect(log.current.readAsStringSync(), '${'c' * 29}\n');
    expect(
      File('${log.current.path}.1').readAsStringSync(),
      '${'a' * 59}\n${'b' * 29}\n',
    );
  });

  test('keeps at most 3 files and drops the oldest', () {
    final log = make(maxBytes: 20);
    for (var i = 0; i < 10; i++) {
      log.append('line-$i-xxxxxxxxxx'); // 17 + newline = 18 bytes: one per file
    }
    final files = log.files;
    expect(files, hasLength(3));
    expect(files[0].readAsStringSync(), 'line-9-xxxxxxxxxx\n');
    expect(files[1].readAsStringSync(), 'line-8-xxxxxxxxxx\n');
    expect(files[2].readAsStringSync(), 'line-7-xxxxxxxxxx\n');
    expect(File('${log.current.path}.3').existsSync(), isFalse);
  });

  test('no file ever exceeds maxBytes, even for huge lines', () {
    final log = make(maxBytes: 50)
      ..append('z' * 500)
      ..append('short')
      ..append('y' * 500);
    for (final f in log.files) {
      expect(f.lengthSync(), lessThanOrEqualTo(50));
    }
    expect(log.files.length, lessThanOrEqualTo(3));
  });

  test('counts bytes, not characters', () {
    final log = make(maxBytes: 20)
      ..append('é' * 8) // 16 bytes + newline = 17
      ..append('é' * 8);
    expect(log.files, hasLength(2));
  });

  test('a real 1 MB limit rotates at 1 MB', () {
    final log = RotatingLogFile(Directory('${tmp.path}/big'));
    final line = 'x' * 1023; // 1024 bytes with the newline
    for (var i = 0; i < 1024; i++) {
      log.append(line);
    }
    expect(log.current.lengthSync(), 1024 * 1024);
    expect(log.files, hasLength(1));
    log.append('next');
    expect(log.files, hasLength(2));
    expect(log.current.readAsStringSync(), 'next\n');
  });

  test('picks up an existing file left by an earlier run', () {
    make(maxBytes: 30).append('a' * 19); // 20 bytes
    final log = make(maxBytes: 30)..append('b' * 19);
    expect(log.files, hasLength(2));
  });

  test('never throws when the path is unusable', () {
    final blocker = File('${tmp.path}/blocker')..writeAsStringSync('x');
    final log = RotatingLogFile(Directory('${blocker.path}/logs'));
    expect(() => log.append('hello'), returnsNormally);
    expect(log.files, isEmpty);
  });

  test('clear deletes every file', () {
    final log = make(maxBytes: 20);
    for (var i = 0; i < 5; i++) {
      log.append('line-$i-xxxxxxxxxx');
    }
    log.clear();
    expect(log.files, isEmpty);
  });
}
