// Test-only: lint noise suppressed on purpose.
// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/log.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late FakeClock clock;
  late FakeActivityRepo repo;
  late StorizeDiagnostics d;
  final origFlutter = FlutterError.onError;
  final origDispatcher = PlatformDispatcher.instance.onError;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storize_qa_r2_hooks_');
    clock = FakeClock(DateTime.utc(2026, 11, 19, 9));
    repo = FakeActivityRepo(clock);
    d = StorizeDiagnostics.create(
      Directory('${tmp.path}/logs'),
      clock: clock,
      release: true,
    );
    d.installCrashHooks();
  });
  tearDown(() {
    FlutterError.onError = origFlutter;
    PlatformDispatcher.instance.onError = origDispatcher;
    tmp.deleteSync(recursive: true);
  });

  Future<List<ActivityEvent>> events() => repo.watchRecent().first;
  String logText() => d.files.current.readAsStringSync();

  test(
    'FlutterError.onError logs but writes no marker and no APP_CRASH',
    () async {
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('overflow'),
          stack: StackTrace.current,
        ),
      );
      expect(logText(), contains('FlutterError.onError'));
      expect(d.marker.file.existsSync(), isFalse);
      expect(await reportPendingCrash(repo, clock, marker: d.marker), isFalse);
      expect(await events(), isEmpty);
    },
  );

  test('PlatformDispatcher.onError -> marker -> one APP_CRASH', () async {
    expect(
      PlatformDispatcher.instance.onError!(
        StateError('async boom'),
        StackTrace.current,
      ),
      isTrue,
    );
    expect(await reportPendingCrash(repo, clock, marker: d.marker), isTrue);
    final e = await events();
    expect(e.single.type, ActivityType.appCrash);
    expect(e.single.payload['errorType'], 'StateError');
  });

  test('zone -> marker -> one APP_CRASH', () async {
    d.recorder.runGuarded<void>(() {
      unawaited(
        Future<void>.delayed(
          Duration.zero,
          () => throw ArgumentError('zone boom'),
        ),
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await reportPendingCrash(repo, clock, marker: d.marker), isTrue);
    expect((await events()).single.payload['errorType'], 'ArgumentError');
  });

  test('sync zone throw -> APP_CRASH', () async {
    d.recorder.runGuarded<void>(() => throw StateError('sync zone'));
    expect(await reportPendingCrash(repo, clock, marker: d.marker), isTrue);
  });

  test(
    'a prior non-fatal FlutterError does not mask a later fatal one',
    () async {
      for (var i = 0; i < 5; i++) {
        FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('glitch $i')),
        );
      }
      PlatformDispatcher.instance.onError!(
        ArgumentError('real crash'),
        StackTrace.current,
      );
      expect(d.marker.read()!.type, 'ArgumentError');
      expect(await reportPendingCrash(repo, clock, marker: d.marker), isTrue);
      expect(
        (await events()).single.payload['summary'],
        contains('real crash'),
      );
    },
  );

  test('fatal marker payload contains no secret', () async {
    PlatformDispatcher.instance.onError!(
      StateError('x sessionid%3DZZQASECRETTHREE9'),
      StackTrace.current,
    );
    await reportPendingCrash(repo, clock, marker: d.marker);
    expect((await events()).single.payload.toString(), isNot(contains('ZZQA')));
  });
}
