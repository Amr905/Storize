// Mapper tests on synthetic fixtures (synthetic, unverified: see
// test/fixtures/synthetic/README.md) and on malformed input.
// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _mapper = EnvelopeMapper();
const _media = MediaMapper();

DateTime _t(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

Map<String, Object?> _story({Map<String, Object?> override = const {}}) => {
  'pk': 'ZZFAKE_s',
  'media_type': 1,
  'taken_at': 1800000000,
  'expiring_at': 1800086400,
  'image_versions2': {
    'candidates': [
      {'url': 'u1', 'width': 10, 'height': 10},
    ],
  },
  ...override,
};

Map<String, Object?> _post({Map<String, Object?> override = const {}}) => {
  'pk': 'ZZFAKE_p',
  'code': 'ZZFAKE_code',
  'media_type': 1,
  'taken_at': 1800000000,
  'image_versions2': {
    'candidates': [
      {'url': 'u1', 'width': 10, 'height': 10},
    ],
  },
  ...override,
};

String? _where(Result<Object?> r) => switch (r.failureOrNull) {
  SchemaChanged(:final where) => where,
  _ => null,
};

void main() {
  group('stories (synthetic, unverified)', () {
    final reels = _mapper.graphqlStories(
      nodeOf(loadSynthetic('story_reel.json')),
    );
    final byId = {
      for (final c in reels['ZZFAKE_user_a']!.items) c.remoteId: c,
    };

    test('AC2 live items are dropped (FR-28); the rest stay', () {
      expect(byId.keys, isNot(contains('ZZFAKE_story_live')));
      expect(byId, hasLength(5));
    });

    test('items come oldest first', () {
      final times = reels['ZZFAKE_user_a']!.items
          .map((c) => c.postedAt)
          .toList();
      expect([...times]..sort(), times);
      expect(times.first, _t(1800000050));
    });

    test('AC2 photo story: expires_at set, best image (largest area)', () {
      final c = byId['ZZFAKE_story_photo']!;
      expect(c.kind, ContentKind.story);
      expect(c.expiresAt, _t(1800086500));
      final slide = c.slides.single;
      expect(slide.type, MediaType.photo);
      expect([slide.width, slide.height], [1080, 1920]);
      expect(slide.url, contains('1080x1920'));
      expect(c.closeFriends, isFalse);
    });

    test('AC2 close friends and link stickers; a sticker without a URL is '
        'skipped', () {
      final c = byId['ZZFAKE_story_cf']!;
      expect(c.closeFriends, isTrue);
      expect(c.extras[linkStickersKey], [
        {'url': 'https://example.test/ZZFAKE_link', 'title': 'ZZFAKE title'},
      ]);
    });

    test('AC3 video with sizes: the largest area wins, not the first', () {
      final slide = byId['ZZFAKE_story_sized']!.slides.single;
      expect([slide.width, slide.height], [1080, 1920]);
      expect(slide.url, endsWith('_102.mp4'));
      expect(slide.duration, const Duration(milliseconds: 7500));
    });

    test('AC3 video without sizes: first version, original size', () {
      final slide = byId['ZZFAKE_story_nosize']!.slides.single;
      expect(slide.url, endsWith('_101.mp4'));
      expect([slide.width, slide.height], [480, 854]);
    });

    test('AC3 DASH-only video: no slide, marked unsupported_stream', () {
      final c = byId['ZZFAKE_story_dash']!;
      expect(c.slides, isEmpty);
      expect(c.extras[unsupportedStreamKey], [0]);
      expect(c.remoteId, 'ZZFAKE_story_dash', reason: 'the row is kept');
    });

    test('reels of another type (highlight, ad) are skipped', () {
      final body = {
        'data': {
          'xdt_api__v1__feed__reels_media': {
            'reels_media': [
              {
                'id': 'ZZFAKE_h',
                'reel_type': 'highlight_reel',
                'items': [_story()],
              },
              {
                'id': 'ZZFAKE_u',
                'items': [_story()],
              },
            ],
          },
        },
      };
      expect(_mapper.graphqlStories(nodeOf(body)).keys, ['ZZFAKE_u']);
    });

    test('a user without items maps to an empty reel', () {
      final body = {
        'data': {
          'xdt_api__v1__feed__reels_media': {
            'reels_media': [
              {
                'id': 'ZZFAKE_u',
                'latest_reel_media': null,
                'items': <Object?>[],
              },
            ],
          },
        },
      };
      final reel = _mapper.graphqlStories(nodeOf(body))['ZZFAKE_u']!;
      expect(reel.items, isEmpty);
      expect(reel.latestReelMedia, isNull);
    });
  });

  group('posts (synthetic, unverified)', () {
    final timeline = _mapper.graphqlTimeline(
      nodeOf(loadSynthetic('timeline.json')),
    );
    RemoteContent map(String pk) {
      final e = timeline.entries.firstWhere((e) => e.pk == pk);
      return _media.post(
        e.node,
        pinned: e.pinned,
        collab: e.isCollabOf('ZZFAKE_user_a'),
      );
    }

    test('AC2 photo with caption and shortcode; best of three candidates', () {
      final p = map('ZZFAKE_post_new_photo');
      expect(p.postType, PostType.photo);
      expect(p.caption, 'ZZFAKE caption');
      expect(p.shortcode, startsWith('ZZFAKE_c_'));
      expect([p.slides.single.width, p.slides.single.height], [2048, 2048]);
    });

    test('AC2 carousel: photo, video (largest) and a DASH-only slide', () {
      final p = map('ZZFAKE_post_carousel');
      expect(p.postType, PostType.carousel);
      expect(p.slides.map((s) => (s.index, s.type)), [
        (0, MediaType.photo),
        (1, MediaType.video),
      ]);
      expect([p.slides[0].width, p.slides[0].height], [1440, 1440]);
      expect(p.slides[1].url, endsWith('_102.mp4'));
      expect(p.slides[1].width, 720);
      expect(p.extras[unsupportedStreamKey], [
        2,
      ], reason: 'slide 3 is DASH only');
      expect(p.postedAt, _t(1800000100), reason: 'the parent time');
    });

    test('AC2 reel: post_type REEL, largest version, duration kept', () {
      final reel = map('ZZFAKE_post_reel');
      expect(reel.postType, PostType.reel);
      expect(reel.slides.single.url, endsWith('_102.mp4'));
      final collab = map('ZZFAKE_post_collab');
      expect(collab.postType, PostType.reel);
      expect(
        collab.slides.single.duration,
        const Duration(milliseconds: 12250),
      );
    });

    test('AC2 a non-reel video is VIDEO', () {
      expect(map('ZZFAKE_post_video').postType, PostType.video);
    });

    test('AC8 markers: pinned and collab', () {
      expect(map('ZZFAKE_post_pinned_fresh').extras, {'pinned': true});
      expect(map('ZZFAKE_post_collab').extras, {'collab': true});
      expect(map('ZZFAKE_post_new_photo').extras, isEmpty);
    });

    test('AC8 collab post belongs to the co-author, a foreign post to nobody '
        'of ours', () {
      final collab = timeline.entries.firstWhere(
        (e) => e.pk == 'ZZFAKE_post_collab',
      );
      expect(collab.belongsTo('ZZFAKE_user_a'), isTrue);
      expect(collab.belongsTo('ZZFAKE_user_b'), isTrue);
      final foreign = timeline.entries.firstWhere(
        (e) => e.pk == 'ZZFAKE_post_foreign',
      );
      expect(foreign.belongsTo('ZZFAKE_user_a'), isFalse);
    });
  });

  group('AC5 missing fields give SchemaChanged(where)', () {
    test('story without expiring_at', () {
      final r = guardMapping(
        () => _media.story(nodeOf(_story(override: {'expiring_at': null}))),
      );
      expect(_where(r), 'response.expiring_at');
    });

    test('story without pk', () {
      final r = guardMapping(
        () => _media.story(nodeOf(_story(override: {'pk': null}))),
      );
      expect(_where(r), 'response.pk');
    });

    test('story with an unknown media_type', () {
      final r = guardMapping(
        () => _media.story(nodeOf(_story(override: {'media_type': 8}))),
      );
      expect(_where(r), 'response.media_type');
    });

    test('photo without candidates', () {
      final r = guardMapping(
        () => _media.post(nodeOf(_post(override: {'image_versions2': null}))),
      );
      expect(_where(r), 'response.image_versions2.candidates');
    });

    test('photo whose candidates lack sizes counts as no candidates', () {
      final r = guardMapping(
        () => _media.post(
          nodeOf(
            _post(
              override: {
                'image_versions2': {
                  'candidates': [
                    {'url': 'u'},
                  ],
                },
              },
            ),
          ),
        ),
      );
      expect(_where(r), 'response.image_versions2.candidates');
    });

    test('video with neither versions nor a manifest', () {
      final r = guardMapping(
        () => _media.post(nodeOf(_post(override: {'media_type': 2}))),
      );
      expect(_where(r), 'response.video_versions');
    });

    test('post without taken_at or shortcode', () {
      expect(
        _where(
          guardMapping(
            () => _media.post(nodeOf(_post(override: {'taken_at': null}))),
          ),
        ),
        'response.taken_at',
      );
      expect(
        _where(
          guardMapping(
            () => _media.post(nodeOf(_post(override: {'code': null}))),
          ),
        ),
        'response.code',
      );
    });

    test('carousel without children, or a child without candidates', () {
      expect(
        _where(
          guardMapping(
            () => _media.post(nodeOf(_post(override: {'media_type': 8}))),
          ),
        ),
        'response.carousel_media',
      );
      final r = guardMapping(
        () => _media.post(
          nodeOf(
            _post(
              override: {
                'media_type': 8,
                'carousel_media': [
                  {'media_type': 1},
                ],
              },
            ),
          ),
        ),
      );
      expect(
        _where(r),
        'response.carousel_media[0].image_versions2.candidates',
      );
    });

    test('wrong type: a string where a number is expected', () {
      final r = guardMapping(
        () => _media.post(nodeOf(_post(override: {'taken_at': 'soon'}))),
      );
      expect(_where(r), 'response.taken_at');
    });

    test('envelopes: no data, no reels_media, no edges, no user key', () {
      expect(
        _where(guardMapping(() => _mapper.graphqlStories(nodeOf({'x': 1})))),
        'response.data.xdt_api__v1__feed__reels_media.reels_media',
      );
      expect(
        _where(
          guardMapping(
            () =>
                _mapper.graphqlTimeline(nodeOf({'data': <String, Object?>{}})),
          ),
        ),
        'response.data.xdt_api__v1__feed__user_timeline_graphql_connection.edges',
      );
      expect(
        _where(
          guardMapping(
            () => _mapper.graphqlProfile(nodeOf({'data': <String, Object?>{}})),
          ),
        ),
        'response.data.user',
      );
      expect(
        _where(guardMapping(() => _mapper.graphqlProfile(nodeOf({'x': 1})))),
        'response.data.user',
      );
    });

    test('user without a username or an id', () {
      expect(
        _where(
          guardMapping(
            () => const UserMapper().profile(nodeOf({'pk': 'ZZFAKE_u'})),
          ),
        ),
        'response.username',
      );
      expect(
        _where(
          guardMapping(
            () => const UserMapper().profile(nodeOf({'username': 'zz'})),
          ),
        ),
        'response.pk',
      );
    });

    test('a null user is not a schema change: it is a null profile', () {
      final (profile, _) = _mapper.graphqlProfile(
        nodeOf(loadSynthetic('failures/graphql_user_null.json')),
      );
      expect(profile, isNull);
    });
  });

  group('user mapping (synthetic REST shape, unverified)', () {
    test(
      'flat followed_by_viewer / blocked_by_viewer and the cheap signals',
      () {
        final p = _mapper.restWebProfile(
          nodeOf(loadSynthetic('rest_web_profile_info.json')),
        )!;
        expect(p.user.remoteUserId, 'ZZFAKE_user_a');
        expect(p.user.isPrivate, isTrue);
        expect(p.user.followedByViewer, isTrue);
        expect(p.user.blockedByViewer, isFalse);
        expect(p.user.displayName, 'ZZFAKE Name');
        expect(p.latestReelMedia, _t(1800000140));
      },
    );

    test('latest_reel_media 0 or null means no story', () {
      for (final v in <Object?>[0, null]) {
        final p = const UserMapper().profile(
          nodeOf({'pk': 'ZZFAKE_u', 'username': 'zz', 'latest_reel_media': v}),
        );
        expect(p.latestReelMedia, isNull);
      }
    });
  });
}
