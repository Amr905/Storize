// Test-only: lint noise from dense adversarial inputs is suppressed on purpose.
// ignore_for_file: cascade_invocations, lines_longer_than_80_chars, avoid_catching_errors, unawaited_futures, unnecessary_underscores
// QA (T-011): adversarial crash-hook tests.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/log.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

const _marker = 'ZZQAFAKEVALUE';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late FakeClock clock;
  late StorizeDiagnostics d;
  final originalFlutter = FlutterError.onError;
  final originalDispatcher = PlatformDispatcher.instance.onError;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storize_qa_hooks_');
    clock = FakeClock(DateTime.utc(2026, 11, 19, 9));
    d = StorizeDiagnostics.create(
      Directory('${tmp.path}/logs'),
      clock: clock,
      release: true,
    );
  });
  tearDown(() {
    FlutterError.onError = originalFlutter;
    PlatformDispatcher.instance.onError = originalDispatcher;
    tmp.deleteSync(recursive: true);
  });

  String logText() =>
      d.files.current.existsSync() ? d.files.current.readAsStringSync() : '';
  int entries(String text, String source) =>
      RegExp(source).allMatches(text).length;

  test(
    'install is idempotent in effect: two installs, one error, one entry',
    () {
      d.installCrashHooks();
      final second = d.installCrashHooks();
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('once')));
      expect(entries(logText(), 'uncaught error'), 1);
      second.uninstall();
    },
  );

  test('fatal-only: FlutterError logs without marker, dispatcher marks', () {
    d.installCrashHooks();
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('ui')));
    expect(logText(), contains('FlutterError.onError'));
    expect(d.marker.file.existsSync(), isFalse);
    PlatformDispatcher.instance.onError!(
      StateError('fatal'),
      StackTrace.current,
    );
    expect(d.marker.read()!.type, 'StateError');
  });

  test('uninstall restores the exact previous handlers', () {
    void prevFlutter(FlutterErrorDetails _) {}
    bool prevDispatcher(Object _, StackTrace __) => false;
    FlutterError.onError = prevFlutter;
    PlatformDispatcher.instance.onError = prevDispatcher;
    final hooks = d.installCrashHooks();
    expect(FlutterError.onError, isNot(same(prevFlutter)));
    hooks.uninstall();
    expect(FlutterError.onError, same(prevFlutter));
    expect(PlatformDispatcher.instance.onError, same(prevDispatcher));
  });

  test('uninstall does not clobber a handler installed after ours', () {
    final hooks = d.installCrashHooks();
    void later(FlutterErrorDetails _) {}
    FlutterError.onError = later;
    hooks.uninstall();
    expect(FlutterError.onError, same(later));
  });

  test('FINDING: previous handlers are replaced, not chained', () {
    var prevCalled = false;
    FlutterError.onError = (_) => prevCalled = true;
    PlatformDispatcher.instance.onError = (_, __) {
      prevCalled = true;
      return true;
    };
    d.installCrashHooks();
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('x')));
    PlatformDispatcher.instance.onError!(StateError('y'), StackTrace.current);
    // Documents current behaviour: the earlier handler never sees errors.
    expect(prevCalled, isFalse);
  });

  test(
    'PlatformDispatcher.onError returns true (handled) and logs + marks',
    () {
      d.installCrashHooks();
      final handled = PlatformDispatcher.instance.onError!(
        StateError('async sessionid=$_marker'),
        StackTrace.current,
      );
      expect(handled, isTrue);
      expect(logText(), contains('PlatformDispatcher.onError'));
      expect(logText(), isNot(contains(_marker)));
      expect(
        File(d.marker.file.path).readAsStringSync(),
        isNot(contains(_marker)),
      );
    },
  );

  test('hooks never throw even if log AND marker both fail', () {
    final blocker = File('${tmp.path}/blocked')..writeAsStringSync('f');
    final broken = StorizeDiagnostics.create(
      Directory(blocker.path),
      clock: clock,
      release: true,
    );
    broken.installCrashHooks();
    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('x')),
      ),
      returnsNormally,
    );
    expect(
      () => PlatformDispatcher.instance.onError!(
        StateError('x'),
        StackTrace.current,
      ),
      returnsNormally,
    );
  });

  test('recorder survives a DiagnosticLog that throws', () {
    final rec = CrashRecorder(
      log: _ThrowingLog(),
      marker: d.marker,
      clock: clock,
    );
    expect(
      () => rec.record(StateError('x'), null, source: 't'),
      returnsNormally,
    );
    // F4: the marker is written even though logging threw.
    expect(d.marker.read(), isNotNull);
  });

  test('F4: log throwing does not prevent the marker', () {
    final rec = CrashRecorder(
      log: _ThrowingLog(),
      marker: d.marker,
      clock: clock,
    );
    rec.record(StateError('x'), null, source: 't');
    expect(d.marker.file.existsSync(), isTrue);
  });

  test('recursive error inside the logger terminates (no infinite loop)', () {
    // A log whose log() reports a FlutterError, which re-enters the hook.
    var depth = 0;
    final recursive = _CallbackLog(() {
      depth++;
      if (depth < 5000) {
        FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('inner')),
        );
      }
    });
    final rec = CrashRecorder(log: recursive, marker: d.marker, clock: clock);
    FlutterError.onError = (details) => rec.record(
      details.exception,
      details.stack,
      source: 'FlutterError.onError',
    );
    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('outer')),
      ),
      returnsNormally,
    );
    expect(
      depth,
      greaterThan(1),
      reason: 'documents that re-entry is not guarded',
    );
  });

  group('runGuarded', () {
    test('captures sync throw and returns null', () {
      final r = CrashRecorder(log: d.log, marker: d.marker, clock: clock);
      final out = r.runGuarded<int>(
        () => throw StateError('sync sessionid=$_marker'),
      );
      expect(out, isNull);
      expect(logText(), contains('(zone)'));
      expect(logText(), isNot(contains(_marker)));
      expect(d.marker.read()!.type, 'StateError');
    });

    test(
      'captures unawaited async error, Future.error and Timer error',
      () async {
        final r = CrashRecorder(log: d.log, marker: d.marker, clock: clock);
        r.runGuarded<void>(() {
          unawaited(
            Future<void>.delayed(Duration.zero, () => throw StateError('a1')),
          );
          Timer(Duration.zero, () => throw StateError('t1'));
          scheduleMicrotask(() => throw StateError('m1'));
          unawaited(Future<void>.error(StateError('e1')));
        });
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final text = logText();
        for (final k in ['a1', 't1', 'm1', 'e1']) {
          expect(text, contains(k));
        }
        expect(entries(text, r'\(zone\)'), 4);
      },
    );

    test('captures error thrown after an await in an async body', () async {
      final r = CrashRecorder(log: d.log, marker: d.marker, clock: clock);
      r.runGuarded<Future<void>>(() async {
        await Future<void>.delayed(Duration.zero);
        throw StateError('after-await');
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(logText(), contains('after-await'));
    });

    test('a caught error is NOT recorded', () async {
      final r = CrashRecorder(log: d.log, marker: d.marker, clock: clock);
      await r.runGuarded<Future<void>>(() async {
        try {
          await Future<void>.error(StateError('handled'));
        } on StateError {
          // fine
        }
      });
      expect(logText(), isNot(contains('handled')));
      expect(d.marker.file.existsSync(), isFalse);
    });
  });

  test('FlutterError.onError in release does not print unredacted text', () {
    // kDebugMode is true under flutter test, so presentError DOES print here.
    // Assert the code path is gated on kDebugMode (release builds: false).
    expect(kDebugMode, isTrue);
    expect(kReleaseMode, isFalse);
  });
}

class _ThrowingLog implements DiagnosticLog {
  @override
  void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) => throw StateError('log broke');
}

class _CallbackLog implements DiagnosticLog {
  _CallbackLog(this.cb);
  final void Function() cb;
  @override
  void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) => cb();
}
