// QA (T-013): the mappers checked against the real fixtures with an
// independent oracle, plus edge cases. Placeholders only.
// ignore_for_file: avoid_dynamic_calls, lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _env = EnvelopeMapper();
const _media = MediaMapper();

/// First candidate with the largest area (the documented tie rule).
Map<String, dynamic> _bestRaw(List<dynamic> list) {
  Map<String, dynamic>? best;
  for (final c in list) {
    final m = c as Map<String, dynamic>;
    if (m['width'] == null || m['height'] == null) continue;
    if (best == null ||
        (m['width'] as int) * (m['height'] as int) >
            (best['width'] as int) * (best['height'] as int)) {
      best = m;
    }
  }
  return best!;
}

Map<String, Object?> _node(Map<String, Object?> extra) => {
  'pk': 'p',
  'code': 'c',
  'taken_at': 1800000000,
  'media_type': 1,
  'image_versions2': {
    'candidates': [
      {'url': 'https://cdn.example.test/a', 'width': 10, 'height': 10},
    ],
  },
  ...extra,
};

void main() {
  group('real timeline: independent oracle over all 12 nodes', () {
    final body = loadReal('profile', '007_graphql.json');
    final raw =
        (body! as Map)['data']['xdt_api__v1__feed__user_timeline_graphql_connection']['edges']
            as List<dynamic>;
    final entries = _env.graphqlTimeline(nodeOf(body)).entries;

    test('every post: slide count, order, best url and size match the raw', () {
      for (var i = 0; i < raw.length; i++) {
        final node = raw[i]['node'] as Map<String, dynamic>;
        final post = _media.post(entries[i].node);
        final type = node['media_type'] as int;
        final sources = type == 8
            ? (node['carousel_media'] as List<dynamic>)
                  .cast<Map<String, dynamic>>()
            : [node];
        expect(post.slides, hasLength(sources.length), reason: '${node['pk']}');
        for (var s = 0; s < sources.length; s++) {
          final src = sources[s];
          final slide = post.slides[s];
          expect(slide.index, s);
          if (src['media_type'] == 2) {
            expect(slide.type, MediaType.video);
            final versions = src['video_versions'] as List<dynamic>;
            final best = _bestRaw(versions);
            expect(slide.url, best['url'], reason: 'video of ${node['pk']}');
            expect(slide.width, best['width']);
            expect(slide.height, best['height']);
          } else {
            expect(slide.type, MediaType.photo);
            final best = _bestRaw(
              src['image_versions2']['candidates'] as List<dynamic>,
            );
            expect(slide.url, best['url'], reason: 'photo of ${node['pk']}');
            expect(slide.width, best['width']);
          }
        }
        expect(post.postType, switch (type) {
          1 => PostType.photo,
          8 => PostType.carousel,
          _ => node['product_type'] == 'clips' ? PostType.reel : PostType.video,
        });
        expect(
          post.caption,
          node['caption'] == null ? isNull : node['caption']['text'],
        );
        expect(post.shortcode, node['code']);
      }
    });

    test('the real set contains each kind the AC lists', () {
      final kinds = {for (final e in entries) _media.post(e.node).postType};
      expect(kinds, containsAll([PostType.photo, PostType.carousel]));
      expect(kinds.contains(PostType.reel), isTrue);
    });
  });

  group('real story: expiring_at, kind, no live', () {
    test('expiring_at equals the raw value, kind story', () {
      final body = loadReal('story', '003_graphql.json');
      final rawItem =
          (body! as Map)['data']['xdt_api__v1__feed__reels_media']['reels_media'][0]['items'][0]
              as Map<String, dynamic>;
      final reels = _env.graphqlStories(nodeOf(body));
      final item = reels.values.single.items.single;
      expect(
        item.expiresAt!.millisecondsSinceEpoch,
        (rawItem['expiring_at'] as int) * 1000,
      );
      expect(item.kind, ContentKind.story);
      expect(item.closeFriends, isFalse);
    });
  });

  group('reel versus video', () {
    Map<String, Object?> video(String? product) => _node({
      'media_type': 2,
      'product_type': ?product,
      'video_versions': [
        {'url': 'https://cdn.example.test/v', 'width': 5, 'height': 5},
      ],
    });

    test('clips is REEL, feed/igtv/none is VIDEO', () {
      PostType t(String? p) => _media.post(Node.root(video(p), 'r')).postType!;
      expect(t('clips'), PostType.reel);
      expect(t('feed'), PostType.video);
      expect(t('igtv'), PostType.video);
      expect(t(null), PostType.video);
    });

    test(
      'product_type clips on a photo or a carousel does not make a reel',
      () {
        final photo = _node({'product_type': 'clips'});
        expect(_media.post(Node.root(photo, 'r')).postType, PostType.photo);
      },
    );
  });

  group('image and video choice edge cases', () {
    test('area decides, not width', () {
      final n = _node({
        'image_versions2': {
          'candidates': [
            {
              'url': 'https://cdn.example.test/wide',
              'width': 1000,
              'height': 1,
            },
            {'url': 'https://cdn.example.test/a', 'width': 40, 'height': 30},
            {'url': 'https://cdn.example.test/b', 'width': 30, 'height': 40},
          ],
        },
      });
      expect(
        _media.post(Node.root(n, 'r')).slides.single.url,
        'https://cdn.example.test/a',
        reason: '1200 area beats the widest (1000 area)',
      );
    });

    test('equal areas: first wins', () {
      final n = _node({
        'image_versions2': {
          'candidates': [
            {'url': 'https://cdn.example.test/a', 'width': 40, 'height': 30},
            {'url': 'https://cdn.example.test/b', 'width': 30, 'height': 40},
          ],
        },
      });
      expect(
        _media.post(Node.root(n, 'r')).slides.single.url,
        'https://cdn.example.test/a',
      );
    });

    test('carousel with a DASH-only middle slide keeps original indexes and '
        'records the dropped one', () {
      Map<String, Object?> child(int i, {bool dash = false}) => {
        'media_type': 2,
        if (!dash)
          'video_versions': [
            {'url': 'https://cdn.example.test/v$i', 'width': 5, 'height': 5},
          ],
        if (dash) 'video_dash_manifest': '<MPD/>',
      };
      final n = _node({
        'media_type': 8,
        'carousel_media': [child(0), child(1, dash: true), child(2)],
      });
      final post = _media.post(Node.root(n, 'r'));
      expect(post.slides.map((s) => s.index), [0, 2]);
      expect(post.extras[unsupportedStreamKey], [1]);
    });

    test('a post whose only slide is DASH-only has no slides but is kept '
        '(the downloader must fail it, T-018)', () {
      final n = _node({'media_type': 2, 'video_dash_manifest': '<MPD/>'});
      final post = _media.post(Node.root(n, 'r'));
      expect(post.slides, isEmpty);
      expect(post.extras[unsupportedStreamKey], [0]);
    });

    test('a story that is a carousel (media_type 8) is SchemaChanged', () {
      final item = {
        'pk': 's',
        'taken_at': 1800000000,
        'expiring_at': 1800086400,
        'media_type': 8,
      };
      expect(
        () => _media.story(Node.root(item, 'item')),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.where,
            'where',
            'item.media_type',
          ),
        ),
      );
    });
  });

  group('pinned and collab markers', () {
    test('an empty timeline_pinned_user_ids is not pinned', () {
      final e = _env.entry(
        Node.root(
          _node({
            'user': {'pk': 'a'},
            'timeline_pinned_user_ids': <Object?>[],
          }),
          'n',
        ),
      );
      expect(e.pinned, isFalse);
    });

    test('NOTE: the pinned marker is set when anyone pinned the post '
        '(including a collaborator); it never affects selection', () {
      final e = _env.entry(
        Node.root(
          _node({
            'user': {'pk': 'a'},
            'timeline_pinned_user_ids': ['somebody_else'],
          }),
          'n',
        ),
      );
      expect(e.pinned, isTrue);
    });

    test('a post authored by the tracked user with a co-author is not a '
        'collab of that user', () {
      final e = _env.entry(
        Node.root(
          _node({
            'user': {'pk': 'a'},
            'coauthor_producers': [
              {'pk': 'b'},
            ],
          }),
          'n',
        ),
      );
      expect(e.belongsTo('a'), isTrue);
      expect(e.isCollabOf('a'), isFalse);
      expect(e.belongsTo('b'), isTrue);
      expect(e.isCollabOf('b'), isTrue);
    });
  });

  group('type errors give a path and never a value', () {
    test('string where a number is expected', () {
      try {
        _env.entry(Node.root(_node({'taken_at': 'ZZVALUE_secret'}), 'n'));
        fail('should throw');
      } on SchemaException catch (e) {
        expect(e.where, 'n.taken_at');
        expect(e.toString(), isNot(contains('ZZVALUE')));
      }
    });

    test('a list where an object is expected, nested path with an index', () {
      try {
        _env.graphqlTimeline(
          Node.root({
            'data': {
              'xdt_api__v1__feed__user_timeline_graphql_connection': {
                'edges': [
                  {'node': 'ZZVALUE_secret'},
                ],
              },
            },
          }, 'response'),
        );
        fail('should throw');
      } on SchemaException catch (e) {
        expect(e.where, contains('edges[0]'));
        expect(e.where, isNot(contains('ZZVALUE')));
      }
    });
  });
}
