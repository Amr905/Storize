import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

final DateTime _t0 = DateTime.utc(2026, 11, 20, 8);

final class _Enq implements DownloadEnqueuer {
  int calls = 0;
  @override
  Future<void> enqueueDownload({required bool wifiOnly}) async => calls++;
}

DownloadPendingResult _dl(DownloadStopReason r, int remaining) =>
    DownloadPendingResult(
      stopReason: r,
      remaining: remaining,
      counts: const [],
      failures: const [],
    );

const _secret =
    'sessionid=SECRET123 https://cdn.example/x?sig=ABC /storage/emulated/0/Pictures/Storize/u/a.jpg';

void main() {
  late FakeDiagnosticLog log;
  late _Enq enq;
  late int downloadRuns;

  TaskRouter make({
    Future<CheckRunResult> Function()? check,
    Future<DownloadPendingResult> Function()? download,
    Future<Object?> Function()? retention,
    Future<Object?> Function()? update,
  }) {
    log = FakeDiagnosticLog();
    enq = _Enq();
    downloadRuns = 0;
    return TaskRouter(
      runCheck: ({required scope, required trigger, targetId, deadline}) =>
          check!(),
      download: ({deadline, policy = ExtractionPolicy.directOnly}) async {
        downloadRuns++;
        return download == null
            ? _dl(DownloadStopReason.completed, 0)
            : download();
      },
      retention: retention ?? () async => null,
      updateCheck: update ?? () async => null,
      settings: FakeSettingsRepo(),
      clock: FakeClock(_t0),
      enqueuer: enq,
      log: log,
    );
  }

  test(
    'unknown/odd task names are deterministic: true, no throw, no name in log',
    () async {
      final r = make();
      for (final n in ['', 'CHECK-STORIES', 'check-stories ', 'zzz$_secret']) {
        expect(await r.route(n), isTrue, reason: n);
      }
      expect(await r.route('nope', {'targetId': 'x', 'manual': 1}), isTrue);
      for (final e in log.entries) {
        expect(e.message.contains('SECRET123'), isFalse);
        expect(e.message.contains('zzz'), isFalse);
      }
    },
  );

  test(
    'a throwing use case (Exception and Error) returns false, never throws',
    () async {
      for (final thrower in <Future<Object?> Function()>[
        () async => throw Exception(_secret),
        () async => throw StateError(_secret),
        () => Future<Object?>.error(_secret),
      ]) {
        final r = make(retention: thrower, update: thrower);
        expect(await r.route('retention'), isFalse);
        expect(await r.route('update-check'), isFalse);
      }
    },
  );

  test('error text (cookie, signed URL, path) never reaches the log', () async {
    final r = make(
      check: () async => throw Exception(_secret),
      download: () async => throw Exception(_secret),
    );
    expect(await r.route('check-stories'), isFalse);
    expect(await r.route('download'), isFalse);
    expect(log.entries, isNotEmpty);
    for (final e in log.entries) {
      for (final bad in ['SECRET123', 'sig=ABC', '/storage', 'cdn.example']) {
        expect(e.message.contains(bad), isFalse, reason: e.message);
      }
    }
  });

  test(
    'roll-over enqueues once per run and the run does not loop itself',
    () async {
      final r = make(
        download: () async => _dl(DownloadStopReason.deadline, 5),
      );
      expect(await r.route('download'), isTrue);
      expect(downloadRuns, 1);
      expect(enq.calls, 1);
    },
  );

  test('a failing download enqueue is a retry result, not a crash', () async {
    final r = TaskRouter(
      runCheck: ({required scope, required trigger, targetId, deadline}) =>
          throw UnimplementedError(),
      download: ({deadline, policy = ExtractionPolicy.directOnly}) async =>
          _dl(DownloadStopReason.deadline, 1),
      retention: () async => null,
      updateCheck: () async => null,
      settings: FakeSettingsRepo(),
      clock: FakeClock(_t0),
      enqueuer: _ThrowingEnq(),
    );
    expect(await r.route('download'), isFalse);
  });

  test('guardrail: no Instagram imports in domain/model; igHttp only reaches '
      'the governed platform assembly', () {
    for (final pkg in ['storize_domain', 'storize_model']) {
      for (final f
          in Directory('../packages/$pkg/lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        expect(
          f.readAsStringSync().contains('package:storize_instagram'),
          isFalse,
          reason: f.path,
        );
      }
    }
    final comp = File('lib/core/composition.dart').readAsStringSync();
    expect(RegExp(r'parts\.igHttp').allMatches(comp).length, 1);
    expect(RegExp(r'parts\.cdnHttp').allMatches(comp).length, 1);
    expect(comp.contains('governor: governor'), isTrue);
    final bg = [
      'lib/background/task_router.dart',
      'lib/background/background_router.dart',
      'lib/background/background_dispatcher.dart',
    ].map((p) => File(p).readAsStringSync()).join();
    expect(bg.contains('IgHttp'), isFalse);
    expect(bg.contains('DartIoHttp'), isFalse);
  });
}

final class _ThrowingEnq implements DownloadEnqueuer {
  @override
  Future<void> enqueueDownload({required bool wifiOnly}) =>
      throw Exception(_secret);
}
