import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/crash_hooks.dart';
import 'package:storize_data/log/crash_marker.dart';
import 'package:storize_data/log/file_diagnostic_log.dart';
import 'package:storize_data/log/rotating_log_file.dart';
import 'package:storize_domain/src/ports/diagnostic_log.dart';
import 'package:storize_domain/src/testing/fake_diagnostic_log.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

const _secret = 'ZZFAKE_SECRET_ONE_a1b2c3';

void main() {
  late Directory tmp;
  late CrashMarker marker;
  late FakeClock clock;
  late FakeActivityRepo repo;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storize_crash_test_');
    marker = CrashMarker(Directory('${tmp.path}/logs'));
    clock = FakeClock(DateTime.utc(2026, 11, 19, 8));
    repo = FakeActivityRepo(clock);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<List<ActivityEvent>> events() => repo.watchRecent().first;

  group('CrashMarker', () {
    test('stores type and redacted first line only', () {
      marker.write(
        StateError('boom sessionid=$_secret\nsecond line Cookie: x=$_secret'),
        DateTime.utc(2026, 11, 19, 7),
      );
      final raw = marker.file.readAsStringSync();
      expect(raw, isNot(contains(_secret)));
      expect(raw, isNot(contains('second line')));
      final info = marker.read()!;
      expect(info.type, 'StateError');
      expect(info.summary, contains('boom'));
      expect(info.at, DateTime.utc(2026, 11, 19, 7));
    });

    test('keeps the first crash when several happen', () {
      marker
        ..write(StateError('first'), clock.now())
        ..write(ArgumentError('second'), clock.now());
      expect(marker.read()!.type, 'StateError');
    });

    test('read is null without a marker; clear is claimable once', () {
      expect(marker.read(), isNull);
      expect(marker.clear(), isFalse);
      marker.write(StateError('x'), clock.now());
      expect(marker.clear(), isTrue);
      expect(marker.clear(), isFalse);
    });

    test('a corrupt marker still counts as a crash of unknown type', () {
      marker.directory.createSync(recursive: true);
      marker.file.writeAsStringSync('{not json');
      final info = marker.read()!;
      expect(info.type, 'Unknown');
      marker.file.writeAsStringSync(jsonEncode([1, 2]));
      expect(marker.read()!.type, 'Unknown');
    });

    test('write never throws, even for an unprintable error or bad path', () {
      expect(() => marker.write(_Unprintable(), clock.now()), returnsNormally);
      final blocker = File('${tmp.path}/b')..writeAsStringSync('x');
      final bad = CrashMarker(Directory('${blocker.path}/d'));
      expect(() => bad.write(StateError('x'), clock.now()), returnsNormally);
      expect(bad.read(), isNull);
    });
  });

  group('reportPendingCrash', () {
    test('records one APP_CRASH activity and clears the marker', () async {
      marker.write(StateError('boom'), DateTime.utc(2026, 11, 19, 7));

      final added = await reportPendingCrash(repo, clock, marker: marker);

      expect(added, isTrue);
      final list = await events();
      expect(list, hasLength(1));
      expect(list.single.type, ActivityType.appCrash);
      expect(list.single.severity, Severity.error);
      expect(list.single.at, clock.now());
      expect(list.single.payload['errorType'], 'StateError');
      expect(list.single.payload['summary'], contains('boom'));
      expect(marker.file.existsSync(), isFalse);
    });

    test('is idempotent', () async {
      marker.write(StateError('boom'), clock.now());
      expect(await reportPendingCrash(repo, clock, marker: marker), isTrue);
      expect(await reportPendingCrash(repo, clock, marker: marker), isFalse);
      expect(await reportPendingCrash(repo, clock, marker: marker), isFalse);
      expect(await events(), hasLength(1));
    });

    test('does nothing without a marker', () async {
      expect(await reportPendingCrash(repo, clock, marker: marker), isFalse);
      expect(await events(), isEmpty);
    });

    test('concurrent callers produce one activity', () async {
      marker.write(StateError('boom'), clock.now());
      final results = await Future.wait([
        reportPendingCrash(repo, clock, marker: marker),
        reportPendingCrash(repo, clock, marker: marker),
      ]);
      expect(results.where((r) => r), hasLength(1));
      expect(await events(), hasLength(1));
    });

    test('payload carries no secrets', () async {
      marker.write(StateError('csrftoken=$_secret'), clock.now());
      await reportPendingCrash(repo, clock, marker: marker);
      expect(
        (await events()).single.payload.toString(),
        isNot(contains(_secret)),
      );
    });

    test('a failed add restores the marker and rethrows', () async {
      marker.write(StateError('boom'), DateTime.utc(2026, 11, 19, 7));
      final failing = _FailingRepo();
      await expectLater(
        reportPendingCrash(failing, clock, marker: marker),
        throwsA(isA<StateError>()),
      );
      final info = marker.read();
      expect(info, isNotNull);
      expect(info!.type, 'StateError');

      expect(await reportPendingCrash(repo, clock, marker: marker), isTrue);
      expect(await events(), hasLength(1));
    });
  });

  group('CrashRecorder', () {
    test('logs redacted error and writes the marker', () {
      final files = RotatingLogFile(Directory('${tmp.path}/logs'));
      CrashRecorder(
        log: FileDiagnosticLog(file: files, clock: clock),
        marker: marker,
        clock: clock,
      ).record(
        StateError('bad sessionid=$_secret'),
        StackTrace.current,
        source: 'test',
      );

      final text = files.current.readAsStringSync();
      expect(text, contains('ERROR [crash] uncaught error (test)'));
      expect(text, contains('StateError'));
      expect(text, isNot(contains(_secret)));
      expect(marker.read()!.type, 'StateError');
    });

    test('runGuarded records async and sync-in-zone errors', () async {
      final log = FakeDiagnosticLog();
      CrashRecorder(log: log, marker: marker, clock: clock).runGuarded(() {
        unawaited(
          Future<void>.delayed(Duration.zero).then<void>((_) {
            throw StateError('async boom');
          }),
        );
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(log.entries, hasLength(1));
      expect(log.entries.single.message, contains('zone'));
      expect(marker.read()!.type, 'StateError');
    });

    test('runGuarded returns the body result', () {
      final recorder = CrashRecorder(
        log: FakeDiagnosticLog(),
        marker: marker,
        clock: clock,
      );
      expect(recorder.runGuarded(() => 42), 42);
    });

    test('record never throws when the log does', () {
      final recorder = CrashRecorder(
        log: _ThrowingLog(),
        marker: marker,
        clock: clock,
      );
      expect(
        () => recorder.record(StateError('x'), null, source: 't'),
        returnsNormally,
      );
    });
  });
}

class _Unprintable {
  @override
  String toString() => throw StateError('no');
}

class _FailingRepo implements ActivityRepo {
  @override
  Future<ActivityEvent> add(ActivityEvent event) =>
      Future.error(StateError('db down'));

  @override
  Future<int> pruneOlderThan(DateTime cutoff) async => 0;

  @override
  Stream<List<ActivityEvent>> watchRecent({
    Set<ActivityType> types = const {},
  }) => const Stream.empty();
}

class _ThrowingLog implements DiagnosticLog {
  @override
  void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) => throw StateError('log down');
}
