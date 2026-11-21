import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_model/storize_model.dart';
import 'package:storize_platform_android/storize_platform_android.dart';
import 'package:workmanager/workmanager.dart';

final class _Rec {
  _Rec(
    this.unique,
    this.task,
    this.c,
    this.policy,
    this.freq,
    this.delay,
    this.expedited,
    this.input,
  );
  final String unique;
  final String task;
  final Constraints c;
  final Object? policy;
  final Duration? freq;
  final Duration? delay;
  final bool expedited;
  final Map<String, dynamic>? input;
}

final class _Client implements WorkmanagerClient {
  final recs = <_Rec>[];
  @override
  Future<void> registerPeriodic(
    String u,
    String t, {
    required Duration frequency,
    required Constraints constraints,
    Duration? initialDelay,
    ExistingPeriodicWorkPolicy policy = ExistingPeriodicWorkPolicy.update,
  }) async => recs.add(
    _Rec(u, t, constraints, policy, frequency, initialDelay, false, null),
  );
  @override
  Future<void> registerOneOff(
    String u,
    String t, {
    required Constraints constraints,
    required ExistingWorkPolicy policy,
    Map<String, dynamic>? inputData,
    bool expedited = false,
  }) async => recs.add(
    _Rec(u, t, constraints, policy, null, null, expedited, inputData),
  );
  @override
  Future<void> cancelAll() async {}
}

final class _ThrowingPlugin extends StorizePlatformAndroid {
  _ThrowingPlugin(this.error);
  final Object error;
  @override
  Future<InsertedMedia?> findByName({
    required String relativeDir,
    required String displayName,
  }) => Future.error(error);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Wi-Fi toggle re-apply: same unique names, update policy, flipped '
      'constraint (replace, not duplicate)', () async {
    final c = _Client();
    final s = WorkmanagerScheduler(c);
    await s.apply(storyMin: 15, postMin: 60, wifiOnly: false);
    await s.apply(storyMin: 15, postMin: 60, wifiOnly: true);
    final first = c.recs.sublist(0, 4);
    final second = c.recs.sublist(4);
    expect(second.map((r) => r.unique), first.map((r) => r.unique));
    expect(c.recs.map((r) => r.unique).toSet(), hasLength(4));
    for (final n in ['check-stories', 'check-posts']) {
      final a = first.firstWhere((r) => r.unique == n);
      final b = second.firstWhere((r) => r.unique == n);
      expect(a.policy, ExistingPeriodicWorkPolicy.update);
      expect(b.policy, ExistingPeriodicWorkPolicy.update);
      expect(a.c.networkType, NetworkType.connected);
      expect(b.c.networkType, NetworkType.unmetered);
    }
  });

  test('minimums are enforced and post start is offset', () async {
    final c = _Client();
    await WorkmanagerScheduler(c)
        .apply(storyMin: 1, postMin: 5, wifiOnly: false);
    final st = c.recs.firstWhere((r) => r.unique == 'check-stories');
    final po = c.recs.firstWhere((r) => r.unique == 'check-posts');
    expect(st.freq, const Duration(minutes: 15));
    expect(po.freq, const Duration(minutes: 60));
    expect(po.delay, isNotNull);
    expect(po.delay! > Duration.zero, isTrue);
    expect(
      c.recs.map((r) => r.task),
      containsAll(['retention', 'update-check']),
    );
  });

  test('checkNow: expedited one-off with network constraint; all = 2 tasks; '
      'target in name and input', () async {
    final c = _Client();
    final s = WorkmanagerScheduler(c);
    await s.checkNow();
    expect(c.recs.map((r) => r.task), ['check-stories', 'check-posts']);
    expect(c.recs.every((r) => r.expedited), isTrue);
    expect(
      c.recs.every((r) => r.c.networkType == NetworkType.connected),
      isTrue,
    );
    await s.checkNow(scope: CheckScope.stories, targetId: 7);
    final r = c.recs.last;
    expect(r.unique, contains('7'));
    expect(r.input!['targetId'], 7);
    expect(r.input!['manual'], true);
  });

  test(
    'enqueueDownload appends one-off download and honours Wi-Fi only',
    () async {
      final c = _Client();
      final s = WorkmanagerScheduler(c);
      await s.enqueueDownload(wifiOnly: true);
      expect(c.recs.single.task, 'download');
      expect(c.recs.single.policy, ExistingWorkPolicy.append);
      expect(c.recs.single.c.networkType, NetworkType.unmetered);
    },
  );

  group('findExisting', () {
    test('passes only dir+name to the owner-scoped native call', () async {
      const ch = MethodChannel('storize/media');
      MethodCall? seen;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (c) async {
            seen = c;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ch, null),
      );
      await PluginGalleryStore(StorizePlatformAndroid())
          .findExisting(relativeDir: 'u', displayName: 'n.jpg');
      expect(seen!.method, 'findByName');
      expect((seen!.arguments as Map).keys.toSet(), {
        'relativeDir',
        'displayName',
      });
    });

    test('unavailable plugin (MissingPluginException) is not found', () async {
      expect(
        await PluginGalleryStore(StorizePlatformAndroid())
            .findExisting(relativeDir: 'u', displayName: 'n.jpg'),
        isNull,
      );
    });

    for (final e in <Object>[
      StateError('x'),
      const FormatException('x'),
      Exception('/storage/emulated/0/secret'),
    ]) {
      test(
        'any failure (${e.runtimeType}) maps to not found',
        () async {
          final store = PluginGalleryStore(_ThrowingPlugin(e));
          expect(
            await store.findExisting(relativeDir: 'u', displayName: 'n.jpg'),
            isNull,
          );
        },
      );
    }
  });
}
