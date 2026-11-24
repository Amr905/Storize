// T-050: in-page fetching is the primary transport; direct HTTP is only the
// fallback for "unavailable".
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart' as d;
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
    'posts and stories use the page first; direct is never called',
    () async {
      final rig = InPageRig(handler: _answer);
      final posts = await rig.run(
        rig.platform.fetchNewPosts(
          'user_1',
          DateTime.utc(2000),
          policy: _policy,
        ),
      );
      expect(posts, isA<Ok<List<RemoteContent>>>());
      expect((posts as Ok<List<RemoteContent>>).value, isNotEmpty);
      final stories = await rig.run(
        rig.platform.fetchStories(['user_1'], policy: _policy),
      );
      expect(stories, isA<Ok<Map<String, List<RemoteContent>>>>());
      expect(rig.http.requests, isEmpty);
      expect(rig.driver.queries, 2);
      // The queries are the allowlisted names, in the page.
      expect(rig.driver.sessions.single.queries, [
        'PolarisProfilePostsQuery',
        'PolarisStoriesV3ReelPageStandaloneQuery',
      ]);
    },
  );

  test('one session per run: one page load (3) plus 1 per query', () async {
    final rig = InPageRig(handler: _answer);
    for (var i = 0; i < 2; i++) {
      await rig.run(
        rig.platform.fetchNewPosts(
          'user_1',
          DateTime.utc(2000),
          policy: _policy,
        ),
      );
    }
    expect(rig.driver.sessions, hasLength(1));
    expect(rig.driver.loads, 1);
    // burst 6: the load (3) and two queries (1 each) leave 1 token.
    expect(await rig.governor.remainingTokens(1), closeTo(1, 0.01));
    // Closing ends the session; the next op opens a new one.
    await rig.platform.closeInPage();
    expect(rig.driver.sessions.single.disposed, isTrue);
    expect(rig.driver.sessions.single.cleared, isTrue);
    await rig.run(
      rig.platform.fetchStories(['user_1'], policy: _policy),
    );
    expect(rig.driver.sessions, hasLength(2));
  });

  test('an unavailable page falls back to direct HTTP', () async {
    final rig = InPageRig(
      // The page has no module: unavailable.
      handler: (n, v) => {'error': 'unavailable:graphql_module'},
      seedDiscovery: true,
      responder: d.graphqlResponder(
        posts: p.loadReal('profile', '007_graphql.json'),
      ),
    );
    final r = await rig.run(
      rig.platform.fetchNewPosts('user_1', DateTime.utc(2000), policy: _policy),
    );
    expect(r, isA<Ok<List<RemoteContent>>>());
    expect(rig.http.requests, isNotEmpty);
    // The page session was closed before the fallback.
    expect(rig.driver.sessions.single.disposed, isTrue);
  });

  test('a page that never gets its tokens is unavailable (ready=no)', () async {
    final rig = InPageRig(
      handler: _answer,
      seedDiscovery: true,
      responder: d.graphqlResponder(
        posts: p.loadReal('profile', '007_graphql.json'),
      ),
    );
    rig.driver.isReady = false;
    final r = await rig.run(
      rig.platform.fetchNewPosts('user_1', DateTime.utc(2000), policy: _policy),
    );
    expect(r, isA<Ok<List<RemoteContent>>>());
    expect(rig.http.requests, isNotEmpty);
    expect(rig.logs, contains('session_open'));
    expect(rig.logs, contains('ready=no'));
  });

  test(
    'no document-start script support: direct fallback, nothing loaded',
    () async {
      final rig = InPageRig(
        handler: _answer,
        documentStart: false,
        seedDiscovery: true,
        responder: d.graphqlResponder(
          posts: p.loadReal('profile', '007_graphql.json'),
        ),
      );
      final r = await rig.run(
        rig.platform.fetchNewPosts(
          'user_1',
          DateTime.utc(2000),
          policy: _policy,
        ),
      );
      expect(r, isA<Ok<List<RemoteContent>>>());
      expect(rig.driver.sessions, isEmpty);
    },
  );

  test('a real failure is final, not a fallback (shielded body)', () async {
    final rig = InPageRig(
      handler: (n, v) => {
        'status': 200,
        'shielded': true,
        'fbError': 1357054,
        'json': {'error': 1357054},
      },
    );
    final r = await rig.run(
      rig.platform.fetchNewPosts('user_1', DateTime.utc(2000), policy: _policy),
    );
    expect(r.failureOrNull, isA<SchemaChanged>());
    expect(rig.http.requests, isEmpty);
  });

  test(
    'a login redirect ends the session as SessionInvalid, no fallback',
    () async {
      final rig = InPageRig(handler: _answer);
      rig.driver.onLoad = (s, url) => s.controller.add(
        const NavigationEvent(
          host: 'www.instagram.com',
          path: '/accounts/login/',
        ),
      );
      final r = await rig.run(
        rig.platform.fetchNewPosts(
          'user_1',
          DateTime.utc(2000),
          policy: _policy,
        ),
      );
      expect(r.failureOrNull, isA<SessionInvalid>());
      expect(rig.http.requests, isEmpty);
      expect(rig.driver.sessions.single.disposed, isTrue);
    },
  );

  group('resolveUser', () {
    test('reads the user from the posts, one query, one load', () async {
      final rig = InPageRig(handler: _answer);
      final r = await rig.run(rig.platform.resolveUser(p.fakeUser));
      final user = (r as Ok<RemoteUser>).value;
      expect(user.remoteUserId, 'user_2');
      expect(user.username, p.fakeUser);
      expect(rig.driver.queries, 1);
      expect(rig.driver.loads, 1);
      expect(rig.http.requests, isEmpty);
    });

    test('an account without posts: profile page, same session', () async {
      final rig = InPageRig(
        handler: (n, v) => script(emptyPosts()),
      );
      rig.driver.onLoad = (s, url) {
        s.controller.add(const LoadStopEvent());
        if (url.path == '/${p.fakeUser}/') {
          s.controller.add(
            p.hookResponse(p.realProfile(), name: p.profileName),
          );
        }
      };
      final r = await rig.run(rig.platform.resolveUser(p.fakeUser));
      expect(r, isA<Ok<RemoteUser>>());
      expect(rig.driver.sessions, hasLength(1));
      expect(rig.driver.sessions.single.loads.map((u) => u.path), [
        '/',
        '/${p.fakeUser}/',
      ]);
      expect(rig.http.requests, isEmpty);
    });

    test('a private or missing profile keeps the existing failure', () async {
      final rig = InPageRig(handler: (n, v) => script(emptyPosts()));
      rig.driver.onLoad = (s, url) {
        s.controller.add(const LoadStopEvent());
        if (url.path == '/${p.fakeUser}/') {
          s.controller.add(
            p.hookResponse({
              'data': {'user': null},
            }, name: p.profileName),
          );
        }
      };
      final r = await rig.run(rig.platform.resolveUser(p.fakeUser));
      expect(r.failureOrNull, isA<TargetNotFound>());
    });
  });

  group('background allowance', () {
    test('by default in-page runs in the background', () async {
      final rig = InPageRig(handler: _answer, runsInBackground: true);
      final r = await rig.run(
        rig.platform.fetchNewPosts(
          'user_1',
          DateTime.utc(2000),
          policy: _policy,
        ),
      );
      expect(r, isA<Ok<List<RemoteContent>>>());
      expect(rig.driver.queries, 1);
      expect(rig.http.requests, isEmpty);
    });

    test('the kill switch sends background work to direct HTTP', () async {
      final rig = InPageRig(
        handler: _answer,
        runsInBackground: true,
        inPageInBackground: () => false,
        seedDiscovery: true,
        responder: d.graphqlResponder(
          posts: p.loadReal('profile', '007_graphql.json'),
        ),
      );
      final r = await rig.run(
        rig.platform.fetchNewPosts(
          'user_1',
          DateTime.utc(2000),
          policy: _policy,
        ),
      );
      expect(r, isA<Ok<List<RemoteContent>>>());
      expect(rig.driver.sessions, isEmpty);
      expect(rig.http.requests, isNotEmpty);
    });

    test('the kill switch does not stop the foreground', () async {
      final rig = InPageRig(
        handler: _answer,
        inPageInBackground: () => false,
      );
      await rig.run(
        rig.platform.fetchNewPosts(
          'user_1',
          DateTime.utc(2000),
          policy: _policy,
        ),
      );
      expect(rig.driver.queries, 1);
    });
  });

  test('the idle timer closes the session', () async {
    final rig = InPageRig(handler: _answer);
    await rig.run(
      rig.platform.fetchNewPosts('user_1', DateTime.utc(2000), policy: _policy),
    );
    rig.manual
        .lastWhere(
          (t) => t.duration == const Duration(minutes: 2) && t.isActive,
        )
        .fire();
    await rig.time.pump();
    expect(rig.driver.sessions.single.disposed, isTrue);
  });

  test('without a script in-page is off and direct runs as before', () async {
    final rig = InPageRig(
      withScript: false,
      seedDiscovery: true,
      responder: d.graphqlResponder(
        posts: p.loadReal('profile', '007_graphql.json'),
      ),
    );
    final r = await rig.run(
      rig.platform.fetchNewPosts('user_1', DateTime.utc(2000), policy: _policy),
    );
    expect(r, isA<Ok<List<RemoteContent>>>());
    expect(rig.driver.sessions, isEmpty);
  });

  test('the client refuses a mutation before the script is called', () async {
    final rig = InPageRig(handler: _answer);
    await rig.run(rig.platform.fetchStories(['user_1'], policy: _policy));
    expect(inPageQueryAllowed('PolarisStoriesV3SeenMutation'), isFalse);
    expect(inPageQueryAllowed('PolarisProfilePostsQuery'), isTrue);
    expect(inPageQueryAllowed('PolarisSomethingMutationQuery'), isFalse);
  });

  test('log lines carry names and counts only, never values', () async {
    final rig = InPageRig(handler: _answer);
    await rig.run(rig.platform.resolveUser(p.fakeUser));
    await rig.run(
      rig.platform.fetchNewPosts('user_1', DateTime.utc(2000), policy: _policy),
    );
    await rig.platform.closeInPage();
    final logs = rig.logs;
    expect(logs, matches(RegExp(r'session_open ms=\d+ ready=yes modules=2')));
    expect(
      logs,
      matches(RegExp(r'op=PolarisProfilePostsQuery status=200 items=\d+')),
    );
    expect(logs, contains('session_close queries=2'));
    for (final secret in [
      p.fakeSessionId,
      p.fakeCsrf,
      p.fakeDtsg,
      p.fakeLsd,
      p.fakeDocId,
      p.fakeUser,
      'user_2',
      'cdninstagram',
    ]) {
      expect(logs, isNot(contains(secret)), reason: secret);
    }
  });
}
