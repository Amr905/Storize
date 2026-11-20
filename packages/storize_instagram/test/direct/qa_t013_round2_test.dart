// QA (T-013 round 2): adversarial probes of the round 2 fixes.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

import '../governor/fake_time.dart';
import 'support.dart';

DateTime _t(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

const _postsKey = 'xdt_api__v1__feed__user_timeline_graphql_connection';

Map<String, Object?> _photo(
  String pk,
  int takenAt, {
  String author = 'ZZ_owner',
  List<String> coauthors = const [],
}) => {
  'pk': pk,
  'code': 'ZZcode$pk',
  'taken_at': takenAt,
  'media_type': 1,
  'user': {'pk': author},
  'owner_id': {'pk': author},
  if (coauthors.isNotEmpty)
    'coauthor_producers': [
      for (final c in coauthors) {'pk': c},
    ],
  'image_versions2': {
    'candidates': [
      {'url': 'https://cdn.example.test/$pk.jpg', 'width': 10, 'height': 10},
    ],
  },
};

Map<String, Object?> _timeline(List<Map<String, Object?>> nodes) => {
  'data': {
    _postsKey: {
      'edges': [
        for (final n in nodes) {'node': n},
      ],
    },
    'xdt_viewer': {
      'user': {'id': viewerId},
    },
  },
};

/// Profile answers carry the id that was asked for and a name per id.
Responder _byId(
  List<Map<String, Object?>> nodes, {
  Map<String, String> names = const {},
}) {
  final posts = _timeline(nodes);
  return (r) {
    switch (friendlyName(r)) {
      case 'PolarisProfilePostsQuery':
        return jsonReply(posts);
      case 'PolarisProfilePageContentQuery':
        final id = variablesOf(r)['id']! as String;
        final body = jsonDecode(
          jsonEncode(loadReal('profile', '004_graphql.json')),
        ) as Map<String, Object?>;
        final user =
            (body['data']! as Map<String, Object?>)['user']!
                as Map<String, Object?>;
        user['pk'] = id;
        user['id'] = id;
        user['username'] = names[id] ?? 'name_$id';
        return jsonReply(body);
    }
    return const IgReply(status: 500);
  };
}

final class _ThrowingCache implements UsernameCache {
  @override
  Future<String?> usernameOf(String userId) async => throw StateError('x');
  @override
  Future<void> remember(String userId, String username) async =>
      throw StateError('x');
}

final class _ThrowingDocIds implements DocIdResolver {
  @override
  Future<String?> docIdFor(GraphqlQuery query) async =>
      throw StateError('ZZFAKE_secret');
}

final class _LateThrowTransport implements IgTransport {
  @override
  String get name => 'late';
  @override
  Future<Result<UserProfile>> userByUsername(String u, IgCall call) =>
      throw UnimplementedError();
  @override
  Future<Result<UserProfile>> userById(String id, IgCall call) async {
    await call(IgRequest.get(path: '/x'));
    throw StateError('ZZFAKE_after_limit');
  }

  @override
  Future<Result<Map<String, StoryReel>>> storyReels(
    List<String> ids,
    IgCall call,
  ) => throw UnimplementedError();
  @override
  Future<Result<Timeline>> timeline(
    String id,
    IgCall call, {
    String? usernameHint,
  }) => throw UnimplementedError();
  @override
  Future<Result<Viewer>> viewer(String own, IgCall call) =>
      throw UnimplementedError();
}

final class _ProbeRig {
  _ProbeRig(Responder responder) {
    governor = RequestGovernor(
      leases: FakeGovernorLeaseRepo(time.clock),
      clock: time.clock,
      holder: 'p',
      config: noJitter,
      delay: time.delay,
    );
    http = FakeIgHttp(responder);
    unawaited(sessions.save(1, fakeSession()));
    probe = IgProbe(
      accountId: 1,
      governor: governor,
      sessions: sessions,
      http: http,
    );
  }

  final FakeTime time = FakeTime();
  late final RequestGovernor governor;
  final FakeSessionStore sessions = FakeSessionStore();
  late final FakeIgHttp http;
  late final IgProbe probe;
}

RemoteMedia _media(String url) =>
    RemoteMedia(index: 0, type: MediaType.photo, url: url, width: 1, height: 1);

void main() {
  group('unexpected_error cannot hide a rate limit', () {
    test(
      'a 429 on the second call of resolveUser is RateLimited and pauses',
      () async {
        final rig = Rig(
          responder: (r) => friendlyName(r) == 'PolarisProfilePostsQuery'
              ? jsonReply(_timeline([_photo('1', 10)]))
              : jsonReply(
                  {'status': 'fail'},
                  status: 429,
                  retryAfter: const Duration(minutes: 9),
                ),
        );
        final r = await rig.run(rig.extractor.resolveUser('name_ZZ_owner'));
        expect(r.failureOrNull, const RateLimited(Duration(minutes: 9)));
        expect(await rig.governor.isPaused(1), isTrue);
      },
    );

    test('a throwing cache neither fails the call nor hides a 429', () async {
      final ok = Rig(
        responder: _byId([_photo('1', 100)], names: {'ZZ_owner': 'me'}),
        usernames: _ThrowingCache(),
      );
      expect(
        (await ok.run(ok.extractor.fetchNewPosts('ZZ_owner', _t(0)))).isOk,
        isTrue,
      );
      final limited = Rig(
        responder: (_) => jsonReply({'status': 'fail'}, status: 429),
        usernames: _ThrowingCache(),
      );
      final r = await limited.run(
        limited.extractor.fetchNewPosts('ZZ_owner', _t(0)),
      );
      expect(r.failureOrNull, isA<RateLimited>());
      expect(await limited.governor.isPaused(1), isTrue);
    });

    test('a transport that throws AFTER a governed 429: the governor is '
        'paused anyway, the caller gets unexpected_error and the next call '
        'is refused as RateLimited', () async {
      final rig = Rig(
        transport: _LateThrowTransport(),
        responder: (_) => jsonReply({'status': 'fail'}, status: 429),
      );
      final first = await rig.run(rig.extractor.latestStoryTime('1'));
      expect(
        first.failureOrNull,
        const UnknownFailure(null, 'unexpected_error'),
      );
      expect(await rig.governor.isPaused(1), isTrue);
      final sent = rig.http.requests.length;
      await rig.run(rig.extractor.latestStoryTime('1'));
      expect(rig.http.requests, hasLength(sent), reason: 'refused, not sent');
      expect(rig.allLogs, isNot(contains('ZZFAKE')));
    });

    test(
      'a throwing DocIdResolver is a Failure without text, nothing sent',
      () async {
        final rig = Rig(
          responder: (_) => throw StateError('never'),
          transport: GraphqlTransport(
            docIds: _ThrowingDocIds(),
            tokens: FakeTokens(),
          ),
        );
        final r = await rig.run(rig.extractor.resolveUser('x'));
        expect(r.failureOrNull, const UnknownFailure(null, 'unexpected_error'));
        expect(rig.http.requests, isEmpty);
        expect(rig.allLogs, isNot(contains('ZZFAKE')));
      },
    );
  });

  group('username check', () {
    test('case, @ and surrounding spaces are normalised', () async {
      final rig = Rig(
        responder: _byId(
          [_photo('1', 10)],
          names: {'ZZ_owner': 'ab_cd.ef'},
        ),
      );
      final r = await rig.run(rig.extractor.resolveUser('  @AB_Cd.EF '));
      expect(r.valueOrNull?.username, 'ab_cd.ef');
    });

    test('inner whitespace, look-alike letters and a trailing dot do not '
        'match', () async {
      for (final asked in ['ab_cd .ef', 'ab_cd.ef.', 'аb_cd.ef']) {
        // last one starts with a Cyrillic a
        final rig = Rig(
          responder: _byId(
            [_photo('1', 10)],
            names: {'ZZ_owner': 'ab_cd.ef'},
          ),
        );
        final r = await rig.run(rig.extractor.resolveUser(asked));
        expect(
          r.failureOrNull,
          const UnknownFailure(null, 'username_mismatch'),
          reason: asked,
        );
      }
    });

    test('NOTE: the Kelvin sign (U+212A) lower-cases to ASCII k, so a '
        'username typed with it passes the comparison (the posts query by '
        'that string would not find the user on Instagram; AddTarget '
        'validates ASCII first)', () async {
      final rig = Rig(
        responder: _byId([_photo('1', 10)], names: {'ZZ_owner': 'kk'}),
      );
      final r = await rig.run(rig.extractor.resolveUser('Kk'));
      expect(r.isOk, isTrue);
    });
  });

  group('majority vote and collab posts', () {
    test('collab posts with co-authors never vote', () async {
      final rig = Rig(
        responder: _byId(
          [
            for (var i = 0; i < 8; i++)
              _photo('c$i', 10 + i, author: 'ZZ_b', coauthors: ['ZZ_owner']),
            _photo('s1', 30),
          ],
          names: {'ZZ_owner': 'me'},
        ),
      );
      final r = await rig.run(rig.extractor.resolveUser('me'));
      expect(r.valueOrNull?.remoteUserId, 'ZZ_owner');
    });

    test(
      'collab posts whose co-author list is missing can win the vote, '
      'but then the username check refuses: never the wrong target',
      () async {
        final rig = Rig(
          responder: _byId(
            [
              for (var i = 0; i < 5; i++) _photo('b$i', 10 + i, author: 'ZZ_b'),
              for (var i = 0; i < 3; i++) _photo('o$i', 30 + i),
            ],
            names: {'ZZ_owner': 'me', 'ZZ_b': 'other'},
          ),
        );
        final r = await rig.run(rig.extractor.resolveUser('me'));
        expect(r.isErr, isTrue);
        expect(
          r.failureOrNull,
          const UnknownFailure(null, 'username_mismatch'),
        );
      },
    );

    test('a tie is username_unresolvable and sends no profile call', () async {
      final rig = Rig(
        responder: _byId([
          _photo('a', 1, author: 'ZZ_b'),
          _photo('b', 2),
        ]),
      );
      final r = await rig.run(rig.extractor.resolveUser('me'));
      expect(
        r.failureOrNull,
        const UnknownFailure(null, 'username_unresolvable'),
      );
      expect(rig.http.requests, hasLength(1));
    });
  });

  group('malformed edges', () {
    test('NOTE: a malformed NEWEST post is skipped: it is not downloaded, '
        'not reported to the caller, only counted in the log', () async {
      final bad = _photo('new', 500)..remove('taken_at');
      final rig = Rig(
        responder: _byId([_photo('old', 100), bad]),
      );
      final r = await rig.run(rig.extractor.fetchNewPosts('ZZ_owner', _t(50)));
      expect(r.valueOrNull!.map((p) => p.remoteId), ['old']);
      expect(rig.allLogs, contains('skipped_malformed=1'));
    });

    test(
      'all edges malformed is SchemaChanged; none are skipped silently',
      () async {
        final rig = Rig(
          responder: _byId([
            _photo('a', 1)..remove('taken_at'),
            _photo('b', 2)..remove('pk'),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchNewPosts('ZZ_owner', _t(0)));
        expect(r.failureOrNull, isA<SchemaChanged>());
      },
    );

    test('a pk without taken_at on the newest edge makes latestPostTime '
        'older: the watermark at add time is then too low', () async {
      final rig = Rig(
        responder: _byId([
          _photo('old', 100),
          _photo('new', 500)..['taken_at'] = 'x',
        ]),
      );
      final r = await rig.run(rig.extractor.latestPostTime('ZZ_owner'));
      expect(r.valueOrNull, _t(100));
    });
  });

  group('session header with control characters', () {
    for (final bad in ['a\r\nb', 'a\nb', 'a\rb']) {
      test('CR/LF in a cookie value is loginRequired, nothing sent, nothing '
          'logged (${bad.codeUnits})', () async {
        final rig = Rig(
          responder: (_) => throw StateError('never'),
          withSession: false,
        );
        await rig.sessions.save(
          1,
          SessionBlob(
            cookies: {
              'sessionid': 'ZZFAKE_sid$bad',
              'ds_user_id': viewerId,
              'csrftoken': fakeCsrf,
            },
            userAgent: fakeAgent,
            capturedAt: DateTime.utc(2026),
          ),
        );
        final r = await rig.run(rig.extractor.verifySession());
        expect(
          r.failureOrNull,
          const SessionInvalid(SessionReason.loginRequired),
        );
        expect(rig.http.requests, isEmpty);
        expect(rig.allLogs, isNot(contains('ZZFAKE')));
      });
    }

    test('N1 (fixed in T-015): non-ASCII in a cookie is caught early: '
        'SessionInvalid, nothing sent, nothing logged', () async {
      final rig = Rig(
        responder: (_) => throw const TransportException('socket'),
        withSession: false,
      );
      await rig.sessions.save(
        1,
        SessionBlob(
          cookies: const {
            'sessionid': 'ZZFAKE_é',
            'ds_user_id': viewerId,
            'csrftoken': fakeCsrf,
          },
          userAgent: fakeAgent,
          capturedAt: DateTime.utc(2026),
        ),
      );
      final r = await rig.run(rig.extractor.verifySession());
      expect(
        r.failureOrNull,
        const SessionInvalid(SessionReason.loginRequired),
      );
      expect(rig.http.requests, isEmpty);
      expect('${r.failureOrNull}${rig.allLogs}', isNot(contains('ZZFAKE')));
    });
  });

  group('CDN allow-list', () {
    test('look-alike, credential, port, scheme and IDN hosts are rejected '
        'without a request', () async {
      final rig = _ProbeRig((_) => const IgReply(status: 200));
      final bad = <String>[
        'https://cdninstagram.com.evil.test/a.jpg',
        'https://evilcdninstagram.com/a.jpg',
        'https://scontent.cdninstagram.com.evil.test/a.jpg',
        'https://scontent.cdninstagram.com@evil.test/a.jpg',
        r'https://evil.test\@scontent.cdninstagram.com/a.jpg',
        'https://evil.test#@scontent.cdninstagram.com/a.jpg',
        'https://evil.test?.cdninstagram.com/a.jpg',
        'https://scontent.cdninstagram.com:8443/a.jpg',
        'https://scontent.cdninstagram.com:80/a.jpg',
        'http://scontent.cdninstagram.com/a.jpg',
        'https://xn--cdninstagram-9xa.com/a.jpg',
        'https://xn--scontent.cdninstagram.com.evil.test/a.jpg',
        'https://scontent.cdninstagram.com./a.jpg',
        'https://scontent.cdninstagram.com%2eevil.test/a.jpg',
        'https://scontent.cdninstagram.com。evil.test/a.jpg',
        'https://notfbcdn.net/a.jpg',
        'https://fbcdn.net.evil.test/a.jpg',
        'https://www.instagram.com/api/v1/feed/reels_media/',
        'https://i.instagram.com/api/v1/users/1/info/',
        '//scontent.cdninstagram.com/a.jpg',
        'scontent.cdninstagram.com/a.jpg',
        'ftp://scontent.cdninstagram.com/a.jpg',
        'https://127.0.0.1/a.jpg',
        'https://[::1]/a.jpg',
        '',
      ];
      final out = await rig.probe.checkCdn({
        for (var i = 0; i < bad.length; i++) '$i': _media(bad[i]),
      });
      final sent = rig.http.requests.map((r) => r.uri.toString()).toList();
      expect(sent, isEmpty, reason: 'requested: $sent');
      expect(out.map((e) => e.outcome), everyElement('rejected'));
    });

    test(
      'the real CDN hosts pass (case-insensitive, explicit 443, apex)',
      () async {
        final rig = _ProbeRig((_) => const IgReply(status: 206));
        final out = await rig.probe.checkCdn({
          'a': _media('https://scontent-xyz1-1.cdninstagram.com/v/a.jpg?x=1'),
          'b': _media('https://SCONTENT.CDNINSTAGRAM.COM:443/a.jpg'),
          'c': _media('https://instagram.fabc1-1.fna.fbcdn.net/a.mp4'),
          'd': _media('https://fbcdn.net/a.mp4'),
        });
        expect(out.map((e) => e.outcome), everyElement('ok'));
        expect(rig.http.requests, hasLength(4));
        for (final r in rig.http.requests) {
          expect(r.headers.keys, ['Range']);
        }
      },
    );
  });
}
