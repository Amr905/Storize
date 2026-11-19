import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/main.dart';
import 'package:storize_data/log/log.dart';
import 'package:storize_domain/testing.dart';

const _secret = 'ZZFAKE_SECRET_ONE_a1b2c3';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late FakeClock clock;
  late StorizeDiagnostics diagnostics;
  CrashHooks? hooks;
  final originalFlutterOnError = FlutterError.onError;
  final originalDispatcherOnError = PlatformDispatcher.instance.onError;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storize_hooks_test_');
    clock = FakeClock(DateTime.utc(2026, 11, 19, 9));
    diagnostics = StorizeDiagnostics.create(
      Directory('${tmp.path}/logs'),
      clock: clock,
      release: true,
    );
  });

  tearDown(() {
    hooks?.uninstall();
    hooks = null;
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalDispatcherOnError;
    tmp.deleteSync(recursive: true);
  });

  String logText() => diagnostics.files.current.readAsStringSync();

  test('FlutterError.onError logs redacted at ERROR but writes no marker', () {
    hooks = diagnostics.installCrashHooks();

    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('widget failed sessionid=$_secret'),
        stack: StackTrace.current,
      ),
    );

    expect(logText(), contains('FlutterError.onError'));
    expect(logText(), contains('StateError'));
    expect(logText(), isNot(contains(_secret)));
    expect(logText(), contains('ERROR'));
    expect(diagnostics.marker.read(), isNull);
  });

  test('PlatformDispatcher.onError writes an entry and reports handled', () {
    hooks = diagnostics.installCrashHooks();

    final handled = PlatformDispatcher.instance.onError!(
      ArgumentError('async failure csrftoken=$_secret'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(logText(), contains('PlatformDispatcher.onError'));
    expect(logText(), contains('ArgumentError'));
    expect(logText(), isNot(contains(_secret)));
    expect(diagnostics.marker.read()!.type, 'ArgumentError');
  });

  test('the background zone helper writes to the same log', () async {
    hooks = diagnostics.installCrashHooks();

    diagnostics.recorder.runGuarded(() {
      unawaited(
        Future<void>.delayed(Duration.zero).then<void>((_) {
          throw const FormatException('zone failure Bearer $_secret');
        }),
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(logText(), contains('(zone)'));
    expect(logText(), contains('FormatException'));
    expect(logText(), isNot(contains(_secret)));
  });

  test('uninstall restores the previous handlers', () {
    final before = FlutterError.onError;
    final dispatcherBefore = PlatformDispatcher.instance.onError;
    final installed = diagnostics.installCrashHooks();
    expect(FlutterError.onError, isNot(same(before)));

    installed.uninstall();

    expect(FlutterError.onError, same(before));
    expect(PlatformDispatcher.instance.onError, dispatcherBefore);
  });

  test(
    'installDiagnostics installs hooks and returns the diagnostics',
    () async {
      final result = await installDiagnostics(open: () async => diagnostics);

      expect(result, same(diagnostics));
      PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.current);
      expect(logText(), contains('uncaught error'));
    },
  );

  test('installDiagnostics survives a failing open', () async {
    final before = FlutterError.onError;

    final result = await installDiagnostics(
      open: () async => throw const FileSystemException('no storage'),
    );

    expect(result, isNull);
    expect(FlutterError.onError, same(before));
  });
}
