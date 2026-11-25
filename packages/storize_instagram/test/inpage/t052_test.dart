// T-052: queries of an open in-page session must not stall behind the
// background reserve, and every query logs a start and an end line.
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

void main() {
  test(
    'a background run does not wait for a token refill after session_open',
    () async {
      final rig = InPageRig(handler: _answer, runsInBackground: true);
      final start = rig.time.clock.now();
      final r = await rig.run(
        RequestGovernor.withPriority(
          RequestPriority.background,
          () => rig.platform.fetchNewPosts(
            'user_1',
            DateTime.utc(2000),
            policy: _policy,
          ),
        ),
      );
      expect(r, isA<Ok<List<RemoteContent>>>());
      final took = rig.time.clock.now().difference(start);
      // Before the fix the query waited ~60 s for one refilled token (the
      // page load left 3, the background query needed 3 + 1).
      expect(took, lessThan(const Duration(seconds: 20)));
      expect(
        rig.governorLogs.where((l) => l.contains('outcome=wait')),
        isEmpty,
      );
      expect(rig.driver.queries, 1);
    },
  );

  test('the page open itself still honours the background reserve', () async {
    final rig = InPageRig(handler: _answer, runsInBackground: true);
    // Leave only 4 tokens: the page load (3) plus the reserve (3) must wait.
    await rig.governor.run(
      accountId: 1,
      cost: RequestCost.api,
      call: () async => 1,
      priority: RequestPriority.interactive,
    );
    await rig.governor.run(
      accountId: 1,
      cost: RequestCost.api,
      call: () async => 1,
      priority: RequestPriority.interactive,
    );
    final start = rig.time.clock.now();
    await rig.run(
      RequestGovernor.withPriority(
        RequestPriority.background,
        () => rig.platform.fetchNewPosts(
          'user_1',
          DateTime.utc(2000),
          policy: _policy,
        ),
      ),
    );
    expect(
      rig.time.clock.now().difference(start),
      greaterThan(const Duration(seconds: 30)),
    );
    expect(
      rig.governorLogs.where((l) => l.contains('outcome=wait')),
      isNotEmpty,
    );
  });

  test('each query logs a start line and an end line with ms', () async {
    final rig = InPageRig(handler: _answer);
    await rig.run(rig.platform.resolveUser(p.fakeUser));
    await rig.run(rig.platform.fetchStories(['user_1'], policy: _policy));
    final lines = [for (final e in rig.log.entries) e.message];
    for (final op in [
      'PolarisProfilePostsQuery',
      'PolarisStoriesV3ReelPageStandaloneQuery',
    ]) {
      final start = lines.indexOf('op=$op start');
      expect(start, isNonNegative, reason: op);
      final end = lines.indexWhere(
        (l) => RegExp('op=$op status=200 items=\\d+ ms=\\d+').hasMatch(l),
      );
      expect(end, greaterThan(start), reason: op);
    }
    expect(lines, contains('session_open start'));
    expect(lines, contains('lease acquire'));
  });

  test('a failing query logs its error with ms and no values', () async {
    final rig = InPageRig(
      handler: (n, v) => {'error': 'bad_json', 'status': 200},
    );
    await rig.run(rig.platform.fetchStories(['user_1'], policy: _policy));
    final lines = [for (final e in rig.log.entries) e.message];
    expect(
      lines.any(
        (l) => RegExp(r'op=\w+ error=bad_json status=200 ms=\d+').hasMatch(l),
      ),
      isTrue,
    );
    for (final secret in [p.fakeSessionId, p.fakeCsrf, p.fakeUser, 'user_1']) {
      expect(lines.join('\n'), isNot(contains(secret)), reason: secret);
    }
  });

  test(
    'a background session keeps one token: two queries, then it waits',
    () async {
      final rig = InPageRig(handler: _answer, runsInBackground: true);
      await rig.run(
        RequestGovernor.withPriority(RequestPriority.background, () async {
          await rig.platform.fetchStories(['user_1'], policy: _policy);
          await rig.platform.fetchStories(['user_1'], policy: _policy);
        }),
      );
      expect(await rig.governor.remainingTokens(1), closeTo(1, 0.01));
      expect(
        rig.governorLogs.where((l) => l.contains('outcome=wait')),
        isEmpty,
      );
    },
  );
}
