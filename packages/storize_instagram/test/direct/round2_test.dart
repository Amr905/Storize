// Long test data lines and const-less fixtures keep the cases readable.
// ignore_for_file: lines_longer_than_80_chars, prefer_const_literals_to_create_immutables
// Round 2 (QA findings F1, F3, F4, F6, F11, F13 and the CR/LF rule): tests
// for what the QA after-fix tests do not already cover.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

DateTime _t(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

final class _MapCache implements UsernameCache {
  final Map<String, String> names = {};
  int gets = 0;

  @override
  Future<String?> usernameOf(String userId) async {
    gets++;
    return names[userId];
  }

  @override
  Future<void> remember(String userId, String username) async =>
      names[userId] = username;
}

final class _ThrowingCache implements UsernameCache {
  @override
  Future<String?> usernameOf(String userId) async => throw StateError('ZZFAKE');

  @override
  Future<void> remember(String userId, String username) async =>
      throw StateError('ZZFAKE');
}

Rig _rig({Object? posts}) {
  final rig = Rig(
    responder: graphqlResponder(
      profile: loadReal('profile', '004_graphql.json'),
      posts: posts ?? loadReal('profile', '007_graphql.json'),
    ),
  );
  return rig;
}

void main() {
  group('QA-F13 username cache: 1 call per posts check when the name is known', () {
    test(
      'a fresh extractor with a persisted name costs 1 call, without 2',
      () async {
        final cold = _rig();
        await cold.run(cold.extractor.latestPostTime('user_1'));
        expect(cold.http.requests, hasLength(2));

        // Same cache object stands for the target repo that survives a restart.
        final cache = _MapCache()..names['user_1'] = 'ZZ_name';
        final rig = Rig(
          responder: graphqlResponder(
            posts: loadReal('profile', '007_graphql.json'),
          ),
          usernames: cache,
        );
        final t = await rig.run(rig.extractor.latestPostTime('user_1'));
        expect(t.isOk, isTrue);
        expect(rig.http.requests, hasLength(1));
        expect(variablesOf(rig.http.requests.single)['username'], 'ZZ_name');
        await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1794700000)));
        expect(rig.http.requests, hasLength(2), reason: '1 call each');
      },
    );

    test('a name learned from a call is written to the cache', () async {
      final cache = _MapCache();
      final rig = Rig(
        responder: graphqlResponder(
          profile: loadReal('profile', '004_graphql.json'),
          posts: loadReal('profile', '007_graphql.json'),
        ),
        usernames: cache,
      );
      await rig.run(rig.extractor.refreshUser('user_1', ''));
      expect(cache.names['user_1'], isNotEmpty);
    });

    test(
      'a cache that throws does not fail the operation or reach the log',
      () async {
        final rig = Rig(
          responder: graphqlResponder(
            profile: loadReal('profile', '004_graphql.json'),
            posts: loadReal('profile', '007_graphql.json'),
          ),
          usernames: _ThrowingCache(),
        );
        final r = await rig.run(rig.extractor.latestPostTime('user_1'));
        expect(r.isOk, isTrue);
        expect(rig.allLogs, isNot(contains('ZZFAKE')));
      },
    );

    test('the in-memory default remembers within one extractor', () async {
      final cache = InMemoryUsernameCache();
      expect(await cache.usernameOf('a'), isNull);
      await cache.remember('a', 'b');
      expect(await cache.usernameOf('a'), 'b');
    });
  });

  group('session header values with CR or LF', () {
    for (final (name, session) in <(String, SessionBlob)>[
      (
        'cookie value',
        SessionBlob(
          cookies: {'sessionid': 'ZZFAKE_a\nX-Evil: 1', 'ds_user_id': 'user_3'},
          userAgent: 'ZZFAKE-UA',
          capturedAt: DateTime.utc(2026),
        ),
      ),
      (
        'cookie name',
        SessionBlob(
          cookies: {'sessionid': 'x', 'ds_user_id': 'user_3', 'a\r': 'y'},
          userAgent: 'ZZFAKE-UA',
          capturedAt: DateTime.utc(2026),
        ),
      ),
      (
        'user agent',
        SessionBlob(
          cookies: {'sessionid': 'x', 'ds_user_id': 'user_3'},
          userAgent: 'ZZFAKE-UA\r\nX-Evil: 1',
          capturedAt: DateTime.utc(2026),
        ),
      ),
    ]) {
      test(
        '$name: SessionInvalid before anything is sent, value not echoed',
        () async {
          final rig = Rig(
            withSession: false,
            responder: (_) => throw StateError('no call'),
          );
          await rig.sessions.save(1, session);
          final r = await rig.run(rig.extractor.fetchStories(['user_1']));
          expect(
            r.failureOrNull,
            const SessionInvalid(SessionReason.loginRequired),
          );
          expect(rig.http.requests, isEmpty);
          expect('${r.failureOrNull}${rig.allLogs}', isNot(contains('ZZFAKE')));
        },
      );
    }
  });

  group('QA-F3 malformed edges are skipped and counted', () {
    Map<String, Object?> posts(List<Map<String, Object?>> nodes) => {
      'data': {
        'xdt_api__v1__feed__user_timeline_graphql_connection': {
          'edges': [
            for (final n in nodes) {'node': n},
          ],
        },
      },
    };
    Map<String, Object?> ok(String pk, int t) => {
      'pk': pk,
      'code': 'ZZFAKE',
      'taken_at': t,
      'media_type': 1,
      'user': {'pk': 'ZZ_owner'},
      'image_versions2': {
        'candidates': [
          {'url': 'u', 'width': 1, 'height': 1},
        ],
      },
    };

    test('mistyped pk, taken_at, pinned and coauthors: skipped or tolerated, '
        'logged as a count with no values', () async {
      final rig = Rig(
        responder: graphqlResponder(
          posts: posts([
            ok('a', 300),
            ok('b', 10)..['pk'] = <String, Object?>{'ZZFAKE': 1},
            ok('c', 10)..['taken_at'] = 'ZZFAKE_text',
            ok('d', 10)..['timeline_pinned_user_ids'] = 'ZZFAKE',
            ok('e', 10)..['coauthor_producers'] = [1, 'x', null],
            {'ZZFAKE': 'not a post'},
          ]),
        ),
        usernames: _MapCache()..names['ZZ_owner'] = 'zz',
      );
      final r = await rig.run(rig.extractor.fetchNewPosts('ZZ_owner', _t(100)));
      expect(r.valueOrNull!.map((p) => p.remoteId), ['a']);
      expect(rig.allLogs, contains('op=fetchNewPosts skipped_malformed=3'));
      expect(rig.allLogs, isNot(contains('ZZFAKE')));
      final t = await rig.run(rig.extractor.latestPostTime('ZZ_owner'));
      expect(t.valueOrNull, _t(300));
    });

    test('all edges malformed: SchemaChanged with the first path', () async {
      final rig = Rig(
        responder: graphqlResponder(
          posts: posts([
            ok('a', 1)..remove('pk'),
            ok('b', 1)..remove('taken_at'),
          ]),
        ),
        usernames: _MapCache()..names['ZZ_owner'] = 'zz',
      );
      final r = await rig.run(rig.extractor.latestPostTime('ZZ_owner'));
      expect(
        r.failureOrNull,
        const SchemaChanged(
          'response.data.xdt_api__v1__feed__user_timeline_graphql_connection.edges[0].node.pk',
        ),
      );
    });

    test('no edges at all is not a failure', () async {
      final rig = Rig(
        responder: graphqlResponder(posts: posts([])),
        usernames: _MapCache()..names['ZZ_owner'] = 'zz',
      );
      final r = await rig.run(rig.extractor.latestPostTime('ZZ_owner'));
      expect(r, const Ok<DateTime?>(null));
    });
  });

  group('QA-F2 username check', () {
    test(
      'case-insensitive match passes, another name is username_mismatch',
      () async {
        Object? profile(String name) {
          final body =
              loadReal('profile', '004_graphql.json')! as Map<String, Object?>;
          return {
            ...body,
            'data': {
              ...(body['data']! as Map<String, Object?>),
              'user': {
                ...((body['data']! as Map<String, Object?>)['user']!
                    as Map<String, Object?>),
                'username': name,
              },
            },
          };
        }

        final ok = Rig(
          responder: graphqlResponder(
            posts: loadReal('profile', '007_graphql.json'),
            profile: profile('ZZ_Name'),
          ),
        );
        expect(
          (await ok.run(ok.extractor.resolveUser('zz_NAME'))).isOk,
          isTrue,
        );
        final bad = Rig(
          responder: graphqlResponder(
            posts: loadReal('profile', '007_graphql.json'),
            profile: profile('ZZ_Other'),
          ),
        );
        expect(
          (await bad.run(bad.extractor.resolveUser('zz_name'))).failureOrNull,
          const UnknownFailure(null, 'username_mismatch'),
        );
      },
    );
  });

  group('QA-F4 redirect variants', () {
    const classifier = FailureClassifier();
    test('challenge, suspended and disabled paths', () {
      for (final p in ['/challenge/', '/challenge/action/ZZ/']) {
        expect(
          classifier.classify(IgReply(status: 302, redirectPath: p)),
          const SessionInvalid(SessionReason.challenge),
          reason: p,
        );
      }
      for (final p in ['/accounts/suspended/', '/accounts/disabled/']) {
        expect(
          classifier.classify(IgReply(status: 302, redirectPath: p)),
          const AccountRestricted(),
          reason: p,
        );
      }
    });
  });

  group('QA-F6 Retry-After as an HTTP-date', () {
    test('a past date is null, a future one is a positive duration', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(
        server.forEach((r) async {
          final when = r.uri.path == '/past'
              ? DateTime.now().toUtc().subtract(const Duration(hours: 1))
              : DateTime.now().toUtc().add(const Duration(minutes: 10));
          r.response
            ..statusCode = 429
            ..headers.set('retry-after', HttpDate.format(when));
          await r.response.close();
        }),
      );
      final base = 'http://127.0.0.1:${server.port}';
      final past = await DartIoHttp().send(
        IgRequest(method: IgMethod.get, uri: Uri.parse('$base/past')),
      );
      final future = await DartIoHttp().send(
        IgRequest(method: IgMethod.get, uri: Uri.parse('$base/future')),
      );
      expect(past.retryAfter, isNull);
      expect(future.retryAfter, greaterThan(const Duration(minutes: 9)));
      expect(future.retryAfter, lessThanOrEqualTo(const Duration(minutes: 10)));
      await server.close(force: true);
    });
  });

  group('QA-F11 IgRequest.toString hides ids', () {
    test('ids in the path are placeholders; no query or form value', () {
      final r = RestRequests.userInfo('ZZFAKE_12345');
      expect(
        r.toString(),
        'IgRequest(get i.instagram.com/api/v1/users/<id>/info/)',
      );
      final feed = RestRequests.userFeed('ZZFAKE_12345');
      expect(feed.toString(), isNot(contains('ZZFAKE')));
      expect(feed.toString(), isNot(contains('count')));
      final post = IgRequest.postForm(
        path: '/api/graphql',
        form: {'fb_dtsg': 'ZZFAKE'},
      );
      expect(post.toString(), 'IgRequest(post www.instagram.com/api/graphql)');
      final cdn = IgRequest(
        method: IgMethod.get,
        uri: Uri.parse(
          'https://scontent.cdninstagram.com/v/ZZFAKE/a.jpg?sig=ZZFAKE',
        ),
      );
      expect(cdn.toString(), isNot(contains('ZZFAKE')));
    });
  });

  group('QA-F1 any thrown error becomes Err', () {
    test(
      'a resolver that throws gives unexpected_error with no text',
      () async {
        final rig = Rig(
          transport: GraphqlTransport(
            docIds: _ThrowingDocIds(),
            tokens: FakeTokens(),
          ),
          responder: (_) => throw StateError('no call'),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(r.failureOrNull, const UnknownFailure(null, 'unexpected_error'));
        expect(rig.allLogs, contains('unexpected_error type=StateError'));
        expect(rig.allLogs, isNot(contains('ZZFAKE')));
      },
    );
  });
}

final class _ThrowingDocIds implements DocIdResolver {
  @override
  Future<String?> docIdFor(GraphqlQuery query) async =>
      throw StateError('ZZFAKE');
}
