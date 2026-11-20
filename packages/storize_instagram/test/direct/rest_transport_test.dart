// The REST transport (IG-1 to IG-5) on synthetic envelopes. The shapes are
// from the TECH_SPEC candidate table: synthetic, unverified.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

IgReply _byPath(IgRequest r) => switch (r.uri.path) {
  '/api/v1/users/web_profile_info/' => jsonReply(
    loadSynthetic('rest_web_profile_info.json'),
  ),
  '/api/v1/users/ZZFAKE_user_a/info/' => jsonReply(
    loadSynthetic('rest_user_info.json'),
  ),
  '/api/v1/feed/reels_media/' => jsonReply(
    loadSynthetic('rest_reels_media.json'),
  ),
  '/api/v1/feed/user/ZZFAKE_user_a/' => jsonReply(
    loadSynthetic('rest_feed_user.json'),
  ),
  '/api/v1/accounts/current_user/' => jsonReply(
    loadSynthetic('rest_current_user.json'),
  ),
  _ => const IgReply(status: 404),
};

Rig _rig({String sessionUserId = 'ZZFAKE_viewer'}) => Rig(
  transport: const RestTransport(),
  sessionUserId: sessionUserId,
  responder: _byPath,
);

DateTime _t(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

void main() {
  test('IG-1 resolveUser: GET web_profile_info?username=, one call', () async {
    final rig = _rig();
    final user = (await rig.run(rig.extractor.resolveUser('zzfake_a')))
        .valueOrNull!;
    expect(user.remoteUserId, 'ZZFAKE_user_a');
    expect(user.isPrivate && user.followedByViewer, isTrue);
    final r = rig.http.requests.single;
    expect(r.method, IgMethod.get);
    expect(r.uri.host, 'www.instagram.com');
    expect(r.uri.queryParameters, {'username': 'zzfake_a'});
  });

  test('IG-1 a null user is TargetNotFound', () async {
    final rig = Rig(
      transport: const RestTransport(),
      responder: (_) => jsonReply({
        'data': {'user': null},
        'status': 'ok',
      }),
    );
    expect(
      (await rig.run(rig.extractor.resolveUser('zz'))).failureOrNull,
      const TargetNotFound(),
    );
  });

  test('IG-3 refreshUser goes to i.instagram.com users/<id>/info', () async {
    final rig = _rig();
    await rig.run(rig.extractor.refreshUser('ZZFAKE_user_a', 'x'));
    final r = rig.http.requests.single;
    expect(r.uri.host, 'i.instagram.com');
    expect(r.uri.path, '/api/v1/users/ZZFAKE_user_a/info/');
  });

  test('IG-2 fetchStories: repeated reel_ids, items mapped', () async {
    final rig = _rig();
    final stories = (await rig.run(
      rig.extractor.fetchStories(['ZZFAKE_user_a', 'ZZFAKE_user_c']),
    )).valueOrNull!;
    expect(stories['ZZFAKE_user_a']!.single.remoteId, 'ZZFAKE_story_rest');
    expect(rig.http.requests.single.uri.queryParametersAll['reel_ids'], [
      'ZZFAKE_user_a',
      'ZZFAKE_user_c',
    ]);
  });

  test(
    'IG-5 fetchNewPosts and latestPostTime: feed/user/<id>?count=12',
    () async {
      final rig = _rig();
      final posts = (await rig.run(
        rig.extractor.fetchNewPosts('ZZFAKE_user_a', _t(1700000000)),
      )).valueOrNull!;
      expect(posts.single.remoteId, 'ZZFAKE_post_rest');
      expect(rig.http.requests.single.uri.queryParameters, {'count': '12'});
      final t = (await rig.run(rig.extractor.latestPostTime('ZZFAKE_user_a')))
          .valueOrNull;
      expect(t, _t(1800000300));
    },
  );

  test(
    'IG-4 verifySession: current_user, viewer id compared with ds_user_id',
    () async {
      final ok = _rig();
      expect((await ok.run(ok.extractor.verifySession())).isOk, isTrue);
      expect(ok.http.requests.single.uri.queryParameters, {'edit': 'true'});
      final bad = _rig(sessionUserId: 'ZZFAKE_someone_else');
      expect(
        (await bad.run(bad.extractor.verifySession())).failureOrNull,
        const SessionInvalid(SessionReason.loginRequired),
      );
    },
  );

  test(
    'the same governor and header rules apply (api cost, session headers)',
    () async {
      final rig = _rig();
      await rig.run(rig.extractor.resolveUser('zz'));
      expect(await rig.governor.remainingTokens(1), 5);
      expect(rig.http.requests.single.headers['User-Agent'], fakeAgent);
    },
  );

  test('a missing items[] is SchemaChanged', () async {
    final rig = Rig(
      transport: const RestTransport(),
      responder: (_) => jsonReply({'status': 'ok'}),
    );
    expect(
      (await rig.run(rig.extractor.latestPostTime('ZZFAKE_user_a')))
          .failureOrNull,
      const SchemaChanged('response.items'),
    );
  });
}
