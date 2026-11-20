// T-014 acceptance tests, against a fake WebView (AC2) and the real
// governor on fake time. Real sanitized captures plus fake page fixtures.

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

NavigationEvent nav(String path, {String host = 'www.instagram.com'}) =>
    NavigationEvent(host: host, path: path);

Rig storyRig({
  Object? body,
  bool runsInBackground = false,
  bool Function()? allowed,
}) => Rig(
  runsInBackground: runsInBackground,
  backgroundAllowed: allowed,
  onLoad: emitting([
    nav('/stories/$fakeUser/'),
    hookResponse(loadPage('unrelated_graphql.json'), name: 'SomeOtherQuery'),
    hookResponse(
      body ?? loadReal('story', '003_graphql.json'),
      name: storiesName,
    ),
  ]),
);

void main() {
  group('AC1 load and capture, AC3 same mappers', () {
    test('stories: loads the story URL and maps the reel like T-013', () async {
      final rig = storyRig();
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      final items = (r as Ok<Map<String, List<RemoteContent>>>).value;
      final expected = const EnvelopeMapper()
          .graphqlStories(Node.root(loadReal('story', '003_graphql.json'), 'r'))
          .values
          .single
          .items;
      expect(items['user_1']!.map((e) => e.remoteId), ['media_16']);
      expect(items['user_1'], expected);
      expect(
        rig.driver.sessions.single.loads.single.toString(),
        'https://www.instagram.com/stories/$fakeUser/',
      );
      expect(items['user_1']!.single.kind, ContentKind.story);
    });

    test('posts: profile URL, same filter as direct mode', () async {
      final posts = loadReal('profile', '007_graphql.json');
      final rig = Rig(
        onLoad: emitting([
          nav('/$fakeUser/'),
          hookResponse(realProfile(), name: profileName),
          hookResponse(posts, name: postsName),
        ]),
      );
      final r = await rig.run(
        rig.extractor.fetchNewPosts('user_1', DateTime.utc(2000)),
      );
      final got = (r as Ok<List<RemoteContent>>).value;
      final timeline = const EnvelopeMapper().graphqlTimeline(
        Node.root(posts, 'r'),
      );
      final expectedIds = {
        for (final e in timeline.entries)
          if (e.belongsTo('user_1')) e.pk,
      };
      expect(got.map((e) => e.remoteId).toSet(), expectedIds);
      expect(got, isNotEmpty);
      final times = got.map((e) => e.postedAt).toList();
      expect([...times]..sort((a, b) => b.compareTo(a)), times);
      expect(
        rig.driver.sessions.single.loads.single.toString(),
        'https://www.instagram.com/$fakeUser/',
      );
    });

    test(
      'latestPostTime is the max taken_at, never the first (pinned)',
      () async {
        final posts = loadReal('profile', '007_graphql.json');
        final rig = Rig(
          onLoad: emitting([hookResponse(posts, name: postsName)]),
        );
        final r = await rig.run(rig.extractor.latestPostTime('user_1'));
        final timeline = const EnvelopeMapper().graphqlTimeline(
          Node.root(posts, 'r'),
        );
        final max = timeline.entries
            .where((e) => e.belongsTo('user_1'))
            .map((e) => e.takenAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        expect((r as Ok<DateTime?>).value, max);
      },
    );

    test('resolveUser and refreshUser use the profile query', () async {
      final rig = Rig(
        onLoad: emitting([hookResponse(realProfile(), name: profileName)]),
      );
      final r = await rig.run(rig.extractor.resolveUser('@$fakeUser'));
      expect((r as Ok<RemoteUser>).value.remoteUserId, 'user_1');
      final same = await rig.run(
        rig.extractor.refreshUser('user_1', fakeUser),
      );
      expect(same, isA<Ok<RemoteUser>>());
      final other = await rig.run(
        rig.extractor.refreshUser('user_9', fakeUser),
      );
      expect(other.failureOrNull, isA<TargetNotFound>());
    });

    test('resolveUser: a profile of another username is a mismatch', () async {
      final rig = Rig(
        onLoad: emitting([
          hookResponse(realProfile(username: 'zzfake_x'), name: profileName),
        ]),
      );
      final r = await rig.run(rig.extractor.resolveUser(fakeUser));
      expect(r.failureOrNull, const UnknownFailure(null, 'username_mismatch'));
    });

    test('latestStoryTime reads latest_reel_media of the profile', () async {
      final rig = Rig(
        onLoad: emitting([hookResponse(realProfile(), name: profileName)]),
      );
      final r = await rig.run(rig.extractor.latestStoryTime('user_1'));
      expect(
        (r as Ok<DateTime?>).value,
        DateTime.fromMillisecondsSinceEpoch(1795115924 * 1000, isUtc: true),
      );
    });

    test('post: the REST media info reply, matched by path', () async {
      const code = 'ZZFAKEcode1';
      final rig = Rig(
        onLoad: emitting([
          hookResponse(
            realMediaInfo(code),
            path: '/api/v1/media/123456/info/',
            docId: null,
            tokens: {},
          ),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchPost(code));
      final post = (r as Ok<RemoteContent>).value;
      expect(post.remoteId, 'media_1');
      expect(post.slides, isNotEmpty);
      expect(rig.driver.sessions.single.loads.single.path, '/p/$code/');
    });

    test('post: a reply for another shortcode is not the answer', () async {
      final rig = Rig(
        onLoad: emitting([
          hookResponse(
            realMediaInfo('ZZFAKEother'),
            path: '/api/v1/media/123456/info/',
          ),
        ]),
      );
      final f = rig.extractor.fetchPost('ZZFAKEcode1');
      await rig.time.pump();
      rig.timers.first.fire();
      expect((await f).failureOrNull, const SchemaChanged('page_timeout'));
    });

    test('post: a bad shortcode is refused without loading', () async {
      final rig = Rig(onLoad: emitting(const []));
      final r = await rig.run(rig.extractor.fetchPost('../etc'));
      expect(r.failureOrNull, isA<TargetNotFound>());
      expect(rig.driver.log, isEmpty);
    });

    test('stories: a reel list without this user keeps waiting', () async {
      final rig = Rig(
        onLoad: emitting([
          hookResponse(loadPage('reels_other_user.json'), name: storiesName),
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
          ),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect((r as Ok<Map<String, List<RemoteContent>>>).value, hasLength(1));
    });

    test(
      'stories: an empty reel list means no stories (not a timeout)',
      () async {
        final rig = Rig(
          onLoad: emitting([
            hookResponse(loadPage('reels_empty.json'), name: storiesName),
            const LoadStopEvent(),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect((r as Ok<Map<String, List<RemoteContent>>>).value, isEmpty);
      },
    );

    test('stories: landing on the profile page means no stories', () async {
      final rig = Rig(
        onLoad: emitting([
          nav('/stories/$fakeUser/'),
          nav('/$fakeUser/'),
          const LoadStopEvent(),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect((r as Ok<Map<String, List<RemoteContent>>>).value, isEmpty);
    });

    test('stories: an unknown username loads nothing', () async {
      final rig = Rig(onLoad: emitting(const []), usernames: const {});
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, const UnknownFailure(null, 'username_unknown'));
      expect(rig.driver.log, isEmpty);
    });

    test('the WebView gets the cookies, the UA and the hook', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      final cfg = rig.driver.sessions.single.config;
      expect(cfg.cookies['sessionid'], fakeSessionId);
      expect(cfg.userAgent, fakeAgent);
      expect(cfg.allowedOrigins, allowedPageOrigins);
      expect(cfg.hookSource, contains('/* hook source */'));
      expect(cfg.hookSource, contains(seenName));
      expect(cfg.hookSource, contains('"includeBody":true'));
    });

    test(
      'a schema change inside the wanted reply is SchemaChanged(path)',
      () async {
        final rig = Rig(
          onLoad: emitting([
            hookResponse({
              'data': {
                'xdt_api__v1__feed__reels_media': {'reels_media': 'oops'},
              },
            }, name: storiesName),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(r.failureOrNull, isA<SchemaChanged>());
        expect(rig.driver.sessions.single.disposed, isTrue);
      },
    );
  });

  group('AC3 timeout', () {
    test('default is 20 seconds and the timer is armed with it', () async {
      final rig = Rig(onLoad: emitting(const []));
      expect(rig.extractor.timeout, const Duration(seconds: 20));
      final f = rig.extractor.fetchStories(['user_1']);
      await rig.time.pump();
      expect(rig.timers.single.duration, const Duration(seconds: 20));
      rig.timers.single.fire();
      expect((await f).failureOrNull, const SchemaChanged('page_timeout'));
    });

    test('the timer is cancelled when the answer comes first', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(rig.timers.single.cancelled, isTrue);
    });
  });

  group('AC4 clean-up in a finally', () {
    test('after success: cleared, then disposed', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(rig.driver.log, ['open', 'load', 'clear', 'dispose']);
    });

    test('after a timeout', () async {
      final rig = Rig(onLoad: emitting(const []));
      final f = rig.extractor.fetchStories(['user_1']);
      await rig.time.pump();
      rig.timers.single.fire();
      await f;
      expect(rig.driver.log, ['open', 'load', 'clear', 'dispose']);
    });

    test('after a failure', () async {
      final rig = Rig(onLoad: emitting([nav('/accounts/login/')]));
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(rig.driver.log, ['open', 'load', 'clear', 'dispose']);
    });

    test('a clear that throws still disposes and keeps the result', () async {
      final rig = Rig(
        clearThrows: true,
        onLoad: emitting([
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
          ),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
      expect(rig.driver.sessions.single.disposed, isTrue);
      expect(rig.allLogs, contains('cleanup_failed step=clear_data'));
      expect(rig.allLogs, isNot(contains('ZZFAKE_cookie')));
    });

    test(
      'a page that cannot open is a failure, nothing left running',
      () async {
        final rig = Rig(openThrows: true, onLoad: emitting(const []));
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(
          r.failureOrNull,
          const UnknownFailure(null, 'webview_unavailable'),
        );
        expect(rig.driver.active, 0);
        expect(rig.allLogs, isNot(contains('ZZFAKE_cookie')));
      },
    );

    test('every load disposes its own WebView: never two at once', () async {
      final rig = Rig(
        usernames: const {'user_1': 'zzfake_a', 'user_2': 'zzfake_b'},
        onLoad: emitting([
          hookResponse(loadPage('reels_empty.json'), name: storiesName),
          const LoadStopEvent(),
        ]),
      );
      await rig.run(rig.extractor.fetchStories(['user_1', 'user_2']));
      expect(rig.driver.sessions, hasLength(2));
      expect(rig.driver.maxActive, 1);
      expect(rig.driver.sessions.every((s) => s.cleared && s.disposed), isTrue);
    });
  });

  group('AC5 message origin', () {
    Future<Rig> runWith(List<PageEvent> events) async {
      final rig = Rig(onLoad: emitting(events));
      final f = rig.extractor.fetchStories(['user_1']);
      await rig.time.pump();
      rig.timers.single.fire();
      expect((await f).failureOrNull, const SchemaChanged('page_timeout'));
      return rig;
    }

    final story = loadReal('story', '003_graphql.json');

    test('a message from another origin is dropped and counted', () async {
      final rig = await runWith([
        hookResponse(story, name: storiesName, pageOrigin: 'https://evil.test'),
      ]);
      expect(rig.extractor.droppedOriginCount, 1);
    });

    test('lookalike and wrong-scheme origins are dropped', () async {
      final rig = await runWith([
        for (final o in [
          'http://www.instagram.com',
          'https://www.instagram.com.evil.test',
          'https://evilinstagram.com',
          'https://www.instagram.com:8443',
          'https://m.instagram.com',
          '',
        ])
          hookResponse(story, name: storiesName, pageOrigin: o),
      ]);
      expect(rig.extractor.droppedOriginCount, 6);
    });

    test('a claimed origin that differs from the frame is dropped', () async {
      final rig = await runWith([
        hookResponse(
          story,
          name: storiesName,
          claimedOrigin: 'https://evil.test',
        ),
      ]);
      expect(rig.extractor.droppedOriginCount, 1);
    });

    test('a request URL on another host is dropped', () async {
      final rig = await runWith([
        hookResponse(story, name: storiesName, host: 'evil.test'),
        hookResponse(story, name: storiesName, host: 'instagram.com.evil.test'),
      ]);
      expect(rig.extractor.droppedOriginCount, 2);
    });

    test('malformed messages are counted apart', () async {
      final rig = await runWith([
        const HookEvent(pageOrigin: okOrigin, args: []),
        const HookEvent(pageOrigin: okOrigin, args: ['not json']),
        const HookEvent(pageOrigin: okOrigin, args: [42]),
      ]);
      expect(rig.extractor.droppedMalformedCount, 3);
      expect(rig.extractor.droppedOriginCount, 0);
    });

    test(
      'https://instagram.com and the www origin are both accepted',
      () async {
        for (final o in ['https://instagram.com', okOrigin]) {
          final rig = Rig(
            onLoad: emitting([
              hookResponse(
                story,
                name: storiesName,
                pageOrigin: o,
                claimedOrigin: o,
              ),
            ]),
          );
          final r = await rig.run(rig.extractor.fetchStories(['user_1']));
          expect(r, isA<Ok<Map<String, List<RemoteContent>>>>(), reason: o);
        }
      },
    );

    test(
      'a hook message from a bad origin never fills the discovery',
      () async {
        final rig = await runWith([
          hookResponse(
            story,
            name: storiesName,
            pageOrigin: 'https://evil.test',
          ),
        ]);
        expect(await rig.discovery.docIdFor(GraphqlQuery.stories), isNull);
        expect(await rig.discovery.tokens(), isNull);
      },
    );
  });

  group('UD-3 seen mutation', () {
    test(
      'blocked notices are counted; the default list names the mutation',
      () async {
        final rig = Rig(
          onLoad: emitting([
            hookBlocked(seenName),
            hookBlocked(seenName),
            hookResponse(
              loadReal('story', '003_graphql.json'),
              name: storiesName,
            ),
          ]),
        );
        await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(rig.extractor.blockedRequestCount, 2);
        expect(PageHookConfig.defaultBlockedFriendlyNames, [seenName]);
        expect(rig.allLogs, contains('blocked=2'));
      },
    );

    test('a blocked notice from a bad origin is not counted', () async {
      final rig = Rig(
        onLoad: emitting([
          hookBlocked(seenName, pageOrigin: 'https://evil.test'),
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
          ),
        ]),
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(rig.extractor.blockedRequestCount, 0);
    });

    test('the list is the default plus the configured names', () async {
      final rig = Rig(
        hookConfig: PageHookConfig(blockedFriendlyNames: ['A_b', 'C1']),
        onLoad: emitting([
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
          ),
        ]),
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      final src = rig.driver.sessions.single.config.hookSource;
      expect(src, contains('"blockedFriendlyNames":["$seenName","A_b","C1"]'));
    });

    test('a name that is not a plain identifier is refused', () {
      for (final bad in ['', 'a b', 'a"b', "x');alert(1);//", 'a-b']) {
        expect(
          () => PageHookConfig(blockedFriendlyNames: [bad]),
          throwsArgumentError,
          reason: bad,
        );
      }
    });
  });

  group('AC7 background gate', () {
    test('background and not allowed: refused, nothing opened', () async {
      final rig = storyRig(runsInBackground: true);
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(
        r.failureOrNull,
        const UnknownFailure(null, 'page_mode_background_disabled'),
      );
      expect(rig.driver.log, isEmpty);
      expect(rig.governorLogs, isEmpty);
    });

    test('background and allowed: runs', () async {
      final rig = storyRig(runsInBackground: true, allowed: () => true);
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
    });

    test('the setting is read at each load', () async {
      var allowed = true;
      final rig = storyRig(runsInBackground: true, allowed: () => allowed);
      await rig.run(rig.extractor.fetchStories(['user_1']));
      allowed = false;
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, isA<UnknownFailure>());
      expect(rig.driver.sessions, hasLength(1));
    });

    test('a gate that throws means not allowed', () async {
      final rig = storyRig(
        runsInBackground: true,
        allowed: () => throw StateError('settings broke'),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, isA<UnknownFailure>());
      expect(rig.driver.log, isEmpty);
    });

    test('foreground ignores the setting', () async {
      final rig = storyRig(allowed: () => false);
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
    });
  });

  group('AC8 governor', () {
    test(
      'a load is one pageLoad call; the third load waits for tokens',
      () async {
        final rig = Rig(
          usernames: const {'a': 'zzfake_a', 'b': 'zzfake_b', 'c': 'zzfake_c'},
          onLoad: emitting([
            hookResponse(loadPage('reels_empty.json'), name: storiesName),
            const LoadStopEvent(),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['a', 'b', 'c']));
        expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
        expect(
          rig.governorLogs.where((l) => l.contains('cost=pageLoad')),
          hasLength(3),
        );
        expect(rig.governorLogs.where((l) => l.contains('cost=api')), isEmpty);
        // Burst 6 = two loads of cost 3; the third had to wait for a refill.
        final waits = [
          for (final l in rig.governorLogs)
            int.parse(RegExp(r'waited_ms=(\d+)').firstMatch(l)!.group(1)!),
        ];
        expect(waits.sublist(0, 2), [0, 0]);
        expect(waits[2], greaterThan(0));
      },
    );

    test('no governed work is nested or left running afterwards', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(rig.time.pendingTimers, 0);
      await rig.time.elapse(const Duration(hours: 2));
      expect(rig.driver.sessions, hasLength(1));
    });

    test(
      'a rate limit pauses the account; the next load opens nothing',
      () async {
        final rig = Rig(
          onLoad: emitting([
            hookResponse(
              loadSynthetic('failures/please_wait.json'),
              name: storiesName,
            ),
          ]),
        );
        final first = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(first.failureOrNull, isA<RateLimited>());
        final second = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(second.failureOrNull, isA<RateLimited>());
        expect(rig.driver.sessions, hasLength(1));
      },
    );
  });

  group('AC11 failures (same map as T-013)', () {
    Future<Failure?> failureOf(List<PageEvent> events) async {
      final rig = Rig(onLoad: emitting(events));
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      return r.failureOrNull;
    }

    test('redirect to the login page', () async {
      expect(
        await failureOf([nav('/accounts/login/')]),
        const SessionInvalid(SessionReason.loginRequired),
      );
    });

    test('redirect to a challenge', () async {
      expect(
        await failureOf([nav('/challenge/ZZFAKE/')]),
        const SessionInvalid(SessionReason.challenge),
      );
    });

    test('redirect to suspended or disabled', () async {
      expect(
        await failureOf([nav('/accounts/suspended/')]),
        isA<AccountRestricted>(),
      );
      expect(
        await failureOf([nav('/accounts/disabled/')]),
        isA<AccountRestricted>(),
      );
    });

    test('a redirect on another host is ignored', () async {
      final rig = Rig(
        onLoad: emitting([nav('/accounts/login/', host: 'evil.test')]),
      );
      final f = rig.extractor.fetchStories(['user_1']);
      await rig.time.pump();
      rig.timers.single.fire();
      expect((await f).failureOrNull, const SchemaChanged('page_timeout'));
    });

    test('HTTP 404, 429, 401 and 500 on the page', () async {
      expect(
        await failureOf([const HttpErrorEvent(404)]),
        isA<TargetNotFound>(),
      );
      expect(await failureOf([const HttpErrorEvent(429)]), isA<RateLimited>());
      expect(
        await failureOf([const HttpErrorEvent(401)]),
        const SessionInvalid(SessionReason.loginRequired),
      );
      expect(
        await failureOf([const HttpErrorEvent(500)]),
        const UnknownFailure(500, 'http_500'),
      );
    });

    test('a load error is a network failure', () async {
      expect(await failureOf([const LoadErrorEvent()]), isA<NetworkFailure>());
    });

    test('please wait inside the wanted reply', () async {
      expect(
        await failureOf([
          hookResponse(
            loadSynthetic('failures/please_wait.json'),
            name: storiesName,
          ),
        ]),
        isA<RateLimited>(),
      );
    });

    test('checkpoint, login, feedback and not-authorized replies', () async {
      Future<Failure?> f(String file) async => failureOf([
        hookResponse(loadSynthetic('failures/$file'), name: storiesName),
      ]);
      expect(
        await f('checkpoint_required.json'),
        const SessionInvalid(SessionReason.challenge),
      );
      expect(
        await f('login_required.json'),
        const SessionInvalid(SessionReason.loginRequired),
      );
      expect(await f('feedback_required.json'), isA<AccountRestricted>());
      expect(await f('not_authorized.json'), isA<TargetNotVisible>());
    });

    test('a null user on the profile page is not found', () async {
      final rig = Rig(
        onLoad: emitting([
          hookResponse(
            loadSynthetic('failures/graphql_user_null.json'),
            name: profileName,
          ),
        ]),
      );
      final r = await rig.run(rig.extractor.resolveUser(fakeUser));
      expect(r.failureOrNull, isA<TargetNotFound>());
    });

    test('a failure in an unrelated reply does not end the run', () async {
      final rig = Rig(
        onLoad: emitting([
          hookResponse(
            loadSynthetic('failures/please_wait.json'),
            name: 'SomeOtherQuery',
          ),
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
          ),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
    });

    test('no stored session: loginRequired, nothing loaded', () async {
      final rig = Rig(withSession: false, onLoad: emitting(const []));
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(
        r.failureOrNull,
        const SessionInvalid(SessionReason.loginRequired),
      );
      expect(rig.driver.log, isEmpty);
    });
  });

  group('AC9 doc_ids and tokens through the direct ports', () {
    test('a run fills the discovery; GraphqlTransport can use it', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(await rig.discovery.docIdFor(GraphqlQuery.stories), fakeDocId);
      expect(await rig.discovery.docIdFor(GraphqlQuery.profile), isNull);
      expect(await rig.discovery.tokens(), {
        'fb_dtsg': fakeDtsg,
        'lsd': fakeLsd,
      });

      final transport = GraphqlTransport(
        docIds: rig.extractor.discovery,
        tokens: rig.extractor.discovery,
      );
      IgRequest? sent;
      final r = await transport.storyReels(['user_1'], (request) async {
        sent = request;
        return Ok(
          loadReal('story', '003_graphql.json')! as Map<String, Object?>,
        );
      });
      expect(r, isA<Ok<Map<String, StoryReel>>>());
      expect(sent!.form!['doc_id'], fakeDocId);
      expect(sent!.form!['fb_dtsg'], fakeDtsg);
    });

    test('a doc_id of a wrong shape and a bad token key are ignored', () async {
      final rig = Rig(
        onLoad: emitting([
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
            docId: 'abc;drop',
            tokens: {'bad key': 'x', 'ok_key': ''},
          ),
        ]),
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(await rig.discovery.docIdFor(GraphqlQuery.stories), isNull);
      expect(await rig.discovery.tokens(), isNull);
    });

    test('values expire (memory only, with a TTL)', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      rig.time.clock.advance(const Duration(minutes: 31));
      expect(await rig.discovery.tokens(), isNull);
      expect(await rig.discovery.docIdFor(GraphqlQuery.stories), fakeDocId);
      rig.time.clock.advance(const Duration(hours: 6));
      expect(await rig.discovery.docIdFor(GraphqlQuery.stories), isNull);
    });

    test('clear() forgets everything; toString shows no values', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      final text = rig.discovery.toString();
      expect(text, isNot(contains(fakeDocId)));
      expect(text, isNot(contains(fakeDtsg)));
      expect(text, 'PageDiscovery(docIds: 1, tokens: true)');
      rig.discovery.clear();
      expect(await rig.discovery.tokens(), isNull);
    });

    test('the tokens handed out are a copy', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      (await rig.discovery.tokens())!['fb_dtsg'] = 'changed';
      expect((await rig.discovery.tokens())!['fb_dtsg'], fakeDtsg);
    });
  });

  group('AC10 nothing sensitive in logs or strings', () {
    test('logs, toStrings and failures hold no secret', () async {
      final rigs = <Rig>[
        storyRig(),
        Rig(onLoad: emitting(const [HttpErrorEvent(404)])),
        Rig(onLoad: emitting([nav('/accounts/login/')])),
        Rig(
          onLoad: emitting([
            hookResponse(
              loadSynthetic('failures/please_wait.json'),
              name: storiesName,
            ),
            hookBlocked(seenName),
          ]),
        ),
      ];
      for (final rig in rigs) {
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        final text =
            '${rig.allLogs} ${r.failureOrNull} ${rig.discovery} '
            '${rig.driver.sessions.single.config} '
            '${hookResponse(const {}, name: storiesName)} '
            '${const HookCapture(path: "/x", status: 1, json: null)}';
        for (final secret in [
          fakeSessionId,
          fakeCsrf,
          fakeDtsg,
          fakeLsd,
          fakeDocId,
          fakeUser,
          'instagram.com/',
          'http',
        ]) {
          expect(text, isNot(contains(secret)), reason: secret);
        }
      }
    });

    test('a log line is made of names, counters and failure types', () async {
      final rig = storyRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(rig.log.entries.map((e) => e.tag).toSet(), {'page'});
      const stats =
          'op=fetchStories accepted=2 dropped_origin=0 '
          'dropped_malformed=0 blocked=0';
      expect(
        rig.log.entries.map((e) => e.message),
        containsAll([stats, 'op=fetchStories ok']),
      );
    });
  });

  group('last resort DOM reading (marked, read-only)', () {
    test('returns only CDN https URLs and logs no URL', () async {
      final rig = Rig(
        onLoad: emitting([const LoadStopEvent()]),
      )..driver.domResult = loadPage('dom_result.json');
      final f = rig.extractor.lastResortDomMedia(fakeUser, stories: true);
      await rig.time.pump();
      // The settle timer is the second timer (the first is the timeout).
      rig.timers.last.fire();
      final media = (await f as Ok<List<DomMedia>>).value;
      expect(media.map((m) => m.isVideo), [false, true]);
      expect(rig.driver.sessions.single.collectCalls, 1);
      expect(
        rig.driver.sessions.single.loads.single.path,
        '/stories/$fakeUser/',
      );
      expect(rig.allLogs, isNot(contains('fbcdn')));
    });
  });
}
