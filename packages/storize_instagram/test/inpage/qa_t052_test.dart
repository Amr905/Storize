// QA T-052: governor accounting and reserve behaviour of in-page sessions.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_model/storize_model.dart';

import '../page/support.dart' as p;
import 'rig.dart';

const ExtractionPolicy _policy = ExtractionPolicy.directThenPage;

Object? _answer(String name, Map<String, Object?> vars) => switch (name) {
  'PolarisProfilePostsQuery' => script(postsFor(p.fakeUser)),
  'PolarisStoriesV3ReelPageStandaloneQuery' => script(emptyStories()),
  _ => {'error': 'unavailable:operation_module'},
};

Future<Duration> _interactiveWait(InPageRig rig) async {
  final t0 = rig.time.clock.now();
  await rig.run(
    rig.governor.run(
      accountId: 1,
      cost: RequestCost.api,
      call: () async => 1,
      priority: RequestPriority.interactive,
    ),
  );
  return rig.time.clock.now().difference(t0);
}

void main() {
  test('page load costs 3 and each query 1 (bucket accounting)', () async {
    final rig = InPageRig(handler: _answer, runsInBackground: true);
    await rig.run(
      RequestGovernor.withPriority(
        RequestPriority.background,
        () => rig.platform.fetchStories(['user_1'], policy: _policy),
      ),
    );
    // burst 6 - 3 (page) - 1 (query) = 2 left: two interactive calls free,
    // the third must wait.
    expect(await _interactiveWait(rig), Duration.zero);
    expect(await _interactiveWait(rig), Duration.zero);
    expect(await _interactiveWait(rig), greaterThan(Duration.zero));
  });

  test('allowUnmetered is off by default: runUnmetered is metered', () async {
    final rig = InPageRig(handler: _answer);
    await rig.run(
      RequestGovernor.runUnmetered(
        () => rig.platform.fetchStories(['user_1'], policy: _policy),
      ),
    );
    expect(rig.governorLogs.where((l) => l.contains('unmetered=yes')), isEmpty);
  });

  test(
    'a background session leaves the reserve for an interactive add',
    () async {
      final rig = InPageRig(handler: _answer, runsInBackground: true);
      // Background session with three queries (all fit before any wait).
      await rig.run(
        RequestGovernor.withPriority(RequestPriority.background, () async {
          await rig.platform.fetchStories(['user_1'], policy: _policy);
          await rig.platform.fetchStories(['user_1'], policy: _policy);
          await rig.platform.fetchStories(['user_1'], policy: _policy);
        }),
      );
      // Session queries keep 1 token for a real interactive add.
      expect(
        await _interactiveWait(rig),
        Duration.zero,
        reason: 'interactive add right after a background session had to wait',
      );
    },
  );
}
