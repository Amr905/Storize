import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/debug/tools/dev_tools_actions.dart';
import 'package:storize_app/debug/tools/dev_tools_screen.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

Target _target(String name, String remoteId) => Target(
  id: Target.unsavedId,
  platform: PlatformId.instagram,
  remoteUserId: remoteId,
  username: name,
  category: TargetCategory.public,
  postsWatermarkAt: DateTime.utc(2026),
  addedAt: DateTime.utc(2026),
);

class _Rig {
  _Rig({
    this.stories,
    this.cookies = 0,
    this.probeReport,
    this.lines = const [],
  }) {
    targets = FakeTargetRepo();
    content = FakeContentRepo(targets: targets);
    actions = DevToolsActions(
      scheduler: scheduler,
      targets: targets,
      content: content,
      clock: FakeClock(),
      pageStories: (id) async {
        pageCalls.add(id);
        return stories ?? const Ok({});
      },
      cookieCount: () async => cookies,
      probe: ({required username, required userId}) async {
        probeCalls.add((username, userId));
        return probeReport ?? const ProbeReport(entries: []);
      },
      logTail: (n) async => lines.take(n).toList(),
    );
  }

  final Result<Map<String, List<RemoteContent>>>? stories;
  final int cookies;
  final ProbeReport? probeReport;
  final List<String> lines;
  final scheduler = FakeScheduler();
  final pageCalls = <String>[];
  final probeCalls = <(String, String)>[];
  late final FakeTargetRepo targets;
  late final FakeContentRepo content;
  late final DevToolsActions actions;
}

void main() {
  test('run check now enqueues the one-off check for all targets', () async {
    final rig = _Rig();
    final out = await rig.actions.runCheckNow();
    expect(rig.scheduler.checkNowCalls, [
      (scope: CheckScope.all, targetId: null),
    ]);
    expect(out, contains('enqueued'));
  });

  test(
    'page-mode load calls the page port with the target remote id',
    () async {
      final rig = _Rig();
      final t = await rig.targets.insert(_target('someone', 'rid_1'));
      final out = await rig.actions.loadStoriesInPageMode(t);
      expect(rig.pageCalls, ['rid_1']);
      expect(out, contains('ok'));
    },
  );

  test('rate limited and busy are shown, not retried', () async {
    final limited = _Rig(stories: const Err(RateLimited(null)));
    final t = await limited.targets.insert(_target('a', 'r'));
    expect(
      await limited.actions.loadStoriesInPageMode(t),
      contains('rate_limited'),
    );
    expect(limited.pageCalls, hasLength(1));
    final busy = _Rig(stories: const Err(NetworkFailure()));
    final t2 = await busy.targets.insert(_target('a', 'r'));
    expect(await busy.actions.loadStoriesInPageMode(t2), contains('busy'));
    expect(busy.pageCalls, hasLength(1));
  });

  test('a thrown error shows only its type', () async {
    final actions = DevToolsActions(
      scheduler: FakeScheduler(),
      targets: FakeTargetRepo(),
      content: FakeContentRepo(),
      clock: FakeClock(),
      pageStories: (_) async => throw StateError('secret-value'),
      cookieCount: () async => throw StateError('secret-value'),
      probe: ({required username, required userId}) async =>
          throw StateError('secret-value'),
      logTail: (_) async => const [],
    );
    final t = _target('a', 'r');
    for (final out in [
      await actions.loadStoriesInPageMode(t),
      await actions.countCookies(),
      await actions.runProbe(t),
    ]) {
      expect(out, contains('StateError'));
      expect(out, isNot(contains('secret-value')));
    }
  });

  test('cookie action shows only the count', () async {
    final out = await _Rig(cookies: 7).actions.countCookies();
    expect(out, 'webview_cookies count=7');
  });

  test('cookie wiring reads only the length of the store', () {
    final src = File('lib/debug/tools/dev_tools_wiring.dart')
        .readAsStringSync();
    expect(src, contains('return cookies.length;'));
    expect(src, isNot(RegExp(r'\bcookies?\.(name|value)\b')));
    expect(src, isNot(RegExp(r'\.(name|value)\b')));
  });

  test('probe passes the target and renders the report as written', () async {
    const report = ProbeReport(
      entries: [
        ProbeEntry(
          id: 'IG-1',
          label: 'users/web_profile_info',
          outcome: 'ok',
          status: 200,
        ),
      ],
    );
    final rig = _Rig(probeReport: report);
    final t = await rig.targets.insert(_target('someone', 'rid_9'));
    final out = await rig.actions.runProbe(t);
    expect(rig.probeCalls, [('someone', 'rid_9')]);
    expect(out, report.render());
  });

  test(
    'seed inserts N placeholder rows under a paused synthetic target',
    () async {
      final rig = _Rig();
      final out = await rig.actions.seedLibrary(25);
      expect(out, 'seed added=25 requested=25');
      final seed = (await rig.targets.getByRemoteUserId(
        PlatformId.instagram,
        DevToolsActions.seedTargetRemoteId,
      ))!;
      expect(seed.status, TargetStatus.paused);
      final rows = await rig.content.listByTarget(seed.id);
      expect(rows, hasLength(25));
      expect(rows.every((r) => r.content.remoteId.startsWith('seed_')), isTrue);
      expect(
        rows.every(
          (r) => r.media.single.sourceUrl.startsWith('placeholder://'),
        ),
        isTrue,
      );
      // Seeding again adds nothing.
      expect(await rig.actions.seedLibrary(25), 'seed added=0 requested=25');
    },
  );

  test('clear seed removes only seeded rows and leaves real data', () async {
    final rig = _Rig();
    final real = await rig.targets.insert(_target('real', 'rid_real'));
    final realRow = await rig.content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: real.id,
        kind: ContentKind.story,
        remoteId: 'real_1',
        postedAt: DateTime.utc(2026),
        slideCount: 1,
        detectedAt: DateTime.utc(2026),
      ),
      const [],
    );
    await rig.actions.seedLibrary(10);
    expect(await rig.actions.clearSeed(), 'seed_cleared removed=10');
    expect(await rig.content.getById(realRow.contentId), isNotNull);
    expect(await rig.targets.getById(real.id), isNotNull);
    expect(
      await rig.targets.getByRemoteUserId(
        PlatformId.instagram,
        DevToolsActions.seedTargetRemoteId,
      ),
      isNull,
    );
    expect(await rig.actions.clearSeed(), 'seed_cleared removed=0');
  });

  test('a non-seed row under the synthetic target survives clear', () async {
    final rig = _Rig();
    await rig.actions.seedLibrary(3);
    final seed = (await rig.targets.getByRemoteUserId(
      PlatformId.instagram,
      DevToolsActions.seedTargetRemoteId,
    ))!;
    await rig.content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: seed.id,
        kind: ContentKind.story,
        remoteId: 'keep_me',
        postedAt: DateTime.utc(2026),
        slideCount: 1,
        detectedAt: DateTime.utc(2026),
      ),
      const [],
    );
    expect(await rig.actions.clearSeed(), 'seed_cleared removed=3');
    expect(await rig.content.listByTarget(seed.id), hasLength(1));
    expect(await rig.targets.getById(seed.id), isNotNull);
  });

  test('recent log returns at most 50 lines', () async {
    final rig = _Rig(lines: [for (var i = 0; i < 80; i++) 'line $i']);
    expect(await rig.actions.recentLog(), hasLength(50));
  });

  testWidgets('screen buttons call the actions', (tester) async {
    final rig = _Rig(cookies: 2, lines: ['accepted=1 blocked=1']);
    await rig.targets.insert(_target('someone', 'rid_1'));
    await tester.pumpWidget(
      MaterialApp(home: DevToolsScreen(actions: rig.actions)),
    );
    await tester.pumpAndSettle();
    Future<void> tap(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tap('Run check now (background)');
    expect(rig.scheduler.checkNowCalls, hasLength(1));
    await tap('Page-mode story load');
    expect(rig.pageCalls, ['rid_1']);
    await tap('Cookie count');
    expect(find.text('webview_cookies count=2'), findsOneWidget);
    await tap('Probe + CDN check');
    expect(rig.probeCalls, hasLength(1));
    await tap('Recent log (50)');
    expect(find.text('accepted=1 blocked=1'), findsOneWidget);
  });

  test('prod main.dart does not import the dev tools', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('debug/tools')));
    expect(main, isNot(contains('main_dev_tools')));
    // Nothing else in lib except the dev entry point and the folder itself.
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final p = f.path.replaceAll(r'\', '/');
      if (!p.endsWith('.dart') ||
          p.contains('lib/debug/tools/') ||
          p.endsWith('lib/main_dev_tools.dart')) {
        continue;
      }
      expect(f.readAsStringSync(), isNot(contains('debug/tools/')), reason: p);
    }
  });
}
