import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:storize_data/log/file_diagnostic_log.dart';
import 'package:storize_data/log/redactor.dart';
import 'package:storize_data/log/rotating_log_file.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

const _secret = 'ZZFAKE_SECRET_ONE_a1b2c3';
const _pinHash = 'v1:120000:c2FsdFNBTFQ=:aGFzaEhBU0g9';

void main() {
  late Directory tmp;
  late RotatingLogFile file;
  late FakeClock clock;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storize_dlog_test_');
    file = RotatingLogFile(Directory('${tmp.path}/logs'));
    clock = FakeClock(DateTime.utc(2026, 11, 19, 6, 55));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String contents() => file.current.readAsStringSync();

  test('writes timestamp, level, tag and message', () {
    FileDiagnosticLog(file: file, clock: clock).log(
      LogLevel.info,
      'governor',
      'run start scope=stories',
    );
    expect(
      contents(),
      '2026-11-19T06:55:00.000Z INFO [governor] run start scope=stories\n',
    );
  });

  test('redacts message, tag, error and stack trace before writing', () {
    final stack = StackTrace.fromString(
      '#0 foo (package:x/x.dart:1)\n#1 bar sessionid=$_secret\n',
    );
    FileDiagnosticLog(file: file, clock: clock).log(
      LogLevel.error,
      'tag-$_pinHash',
      'failed Cookie: sessionid=$_secret',
      error: const FormatException('bad csrftoken=$_secret and $_pinHash'),
      stack: stack,
    );
    final text = contents();
    expect(text, isNot(contains(_secret)));
    expect(text, isNot(contains('c2FsdFNBTFQ')));
    expect(text, contains('FormatException'));
    expect(text, contains('#0 foo (package:x/x.dart:1)'));
    expect(text, contains(Redactor.mask));
  });

  test('an error whose toString throws does not break logging', () {
    final log = FileDiagnosticLog(file: file, clock: clock);
    expect(
      () => log.log(LogLevel.error, 't', 'm', error: _Unprintable()),
      returnsNormally,
    );
    expect(contents(), contains('<unprintable>'));
  });

  test('drops lines below minLevel', () {
    FileDiagnosticLog(file: file, clock: clock)
      ..log(LogLevel.debug, 't', 'hidden')
      ..log(LogLevel.info, 't', 'shown');
    expect(contents(), isNot(contains('hidden')));
    expect(contents(), contains('shown'));
  });

  test('debug builds can log debug lines', () {
    FileDiagnosticLog(file: file, clock: clock, minLevel: LogLevel.debug).log(
      LogLevel.debug,
      't',
      'detail',
    );
    expect(contents(), contains('DEBUG [t] detail'));
  });

  test('console echo is redacted and off by default', () {
    final echoed = <String>[];
    FileDiagnosticLog(
      file: file,
      clock: clock,
      console: true,
      consoleSink: echoed.add,
    ).log(LogLevel.warn, 't', 'x sessionid=$_secret');
    expect(echoed, hasLength(1));
    expect(echoed.single, isNot(contains(_secret)));

    final quiet = <String>[];
    FileDiagnosticLog(file: file, clock: clock, consoleSink: quiet.add).log(
      LogLevel.warn,
      't',
      'm',
    );
    expect(quiet, isEmpty);
  });

  test('never throws when the file cannot be written', () {
    final blocker = File('${tmp.path}/blocker')..writeAsStringSync('x');
    final bad = RotatingLogFile(Directory('${blocker.path}/logs'));
    expect(
      () => FileDiagnosticLog(file: bad, clock: clock).log(
        LogLevel.error,
        't',
        'm',
      ),
      returnsNormally,
    );
  });

  test('bridges the logging package, mapping levels and names', () async {
    final root = Logger.detached('root')..level = Level.ALL;
    final log = FileDiagnosticLog(file: file, clock: clock);
    final detach = FileDiagnosticLog.bridgeLogging(log, root: root);

    Logger.detached('x');
    root
      ..info('hello')
      ..warning('careful Bearer $_secret')
      ..severe('boom', StateError('e'))
      ..fine('too detailed');
    await Future<void>.delayed(Duration.zero);
    detach();
    root.info('after detach');
    await Future<void>.delayed(Duration.zero);

    final text = contents();
    expect(text, contains('INFO [root] hello'));
    expect(text, contains('WARN [root] careful Bearer ${Redactor.mask}'));
    expect(text, contains('ERROR [root] boom'));
    expect(text, contains('StateError'));
    expect(text, isNot(contains('too detailed')));
    expect(text, isNot(contains('after detach')));
    expect(text, isNot(contains(_secret)));
  });

  test('FakeClock timestamps are used', () {
    final log = FileDiagnosticLog(file: file, clock: clock)
      ..log(LogLevel.info, 't', 'a');
    clock.advance(const Duration(minutes: 5));
    log.log(LogLevel.info, 't', 'b');
    final lines = contents().trim().split('\n');
    expect(lines[0], startsWith('2026-11-19T06:55:00.000Z'));
    expect(lines[1], startsWith('2026-11-19T07:00:00.000Z'));
  });
}

class _Unprintable {
  @override
  String toString() => throw StateError('no');
}
