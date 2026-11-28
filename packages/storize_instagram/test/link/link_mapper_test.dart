// T-060 (FR-80): the shortcode__web_info and highlight-owner mappers, on a
// synthetic fixture (ZZFAKE_ values, unverified shapes beyond the Lead's
// 2026-11-28 ground truth).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _mapper = EnvelopeMapper();

Map<String, Object?> _fixture() =>
    jsonDecode(jsonEncode(loadSynthetic('shortcode_web_info.json')))
        as Map<String, Object?>;

Map<String, Object?> _item(Map<String, Object?> body) =>
    ((((body['data']! as Map)['xdt_api__v1__media__shortcode__web_info']!
                    as Map)['items']!
                as List)
            .first)
        as Map<String, Object?>;

void main() {
  group('graphqlShortcodeWebInfo', () {
    test('maps a carousel post and its owner with the v1 mapper', () {
      final r = _mapper.graphqlShortcodeWebInfo(Node.root(_fixture(), 'r'))!;
      final (profile, post) = r;
      expect(profile.user.remoteUserId, 'ZZFAKE_user_a');
      expect(profile.user.username, 'zzfake_user_a');
      expect(profile.user.displayName, 'ZZFAKE Name');
      expect(post.kind, ContentKind.post);
      expect(post.remoteId, 'ZZFAKE_link_post');
      expect(post.shortcode, 'ZZFAKE_c_link');
      expect(post.postType, PostType.carousel);
      expect(post.caption, 'ZZFAKE link caption');
      expect(post.slides, hasLength(2));
      expect(post.slides[0].type, MediaType.photo);
      expect(post.slides[1].type, MediaType.video);
      expect(
        post.postedAt,
        DateTime.fromMillisecondsSinceEpoch(1800000100 * 1000, isUtc: true),
      );
    });

    test('a reel is a post of type reel', () {
      final body = _fixture();
      final item = _item(body)
        ..['media_type'] = 2
        ..['product_type'] = 'clips'
        ..remove('carousel_media')
        ..['image_versions2'] = {
          'candidates': [
            {
              'url': 'https://cdn.example.test/ZZFAKE_r.jpg',
              'width': 9,
              'height': 16,
            },
          ],
        }
        ..['video_versions'] = [
          {'type': 101, 'url': 'https://cdn.example.test/ZZFAKE_r.mp4'},
        ];
      expect(item['product_type'], 'clips');
      final (_, post) = _mapper.graphqlShortcodeWebInfo(Node.root(body, 'r'))!;
      expect(post.postType, PostType.reel);
      expect(post.slides.single.type, MediaType.video);
    });

    test('an empty or null item list is "not found" (null)', () {
      for (final info in <Object?>[
        {'items': <Object?>[]},
        {'items': null},
        null,
      ]) {
        final body = {
          'data': {'xdt_api__v1__media__shortcode__web_info': info},
        };
        expect(_mapper.graphqlShortcodeWebInfo(Node.root(body, 'r')), isNull);
      }
    });

    test('a reply without the key is a schema change', () {
      expect(
        () => _mapper.graphqlShortcodeWebInfo(
          Node.root({'data': <String, Object?>{}}, 'r'),
        ),
        throwsA(isA<SchemaException>()),
      );
    });

    test('an item without an owner username is a schema change', () {
      final body = _fixture();
      (_item(body)['user']! as Map).remove('username');
      expect(
        () => _mapper.graphqlShortcodeWebInfo(Node.root(body, 'r')),
        throwsA(isA<SchemaException>()),
      );
    });
  });

  group('graphqlHighlightWithOwner', () {
    Map<String, Object?> reel() {
      final body = jsonDecode(
        jsonEncode(loadSynthetic('highlight_reel.json')),
      ) as Map<String, Object?>;
      final reels =
          ((body['data']! as Map)['xdt_api__v1__feed__reels_media']!
                  as Map)['reels_media']!
              as List;
      (((reels.first as Map)['user']) as Map)['username'] = 'zzfake_user_a';
      return body;
    }

    test('gives the owner and the items of the asked highlight', () {
      final r = _mapper.graphqlHighlightWithOwner(
        Node.root(reel(), 'r'),
        'ZZFAKE_hl_1',
      )!;
      expect(r.$1.user.username, 'zzfake_user_a');
      expect(r.$2, isNotEmpty);
      expect(r.$2.every((c) => c.kind == ContentKind.highlight), isTrue);
    });

    test('another id gives null; no username is a schema change', () {
      expect(
        _mapper.graphqlHighlightWithOwner(Node.root(reel(), 'r'), 'nope'),
        isNull,
      );
      expect(
        () => _mapper.graphqlHighlightWithOwner(
          Node.root(loadSynthetic('highlight_reel.json'), 'r'),
          'ZZFAKE_hl_1',
        ),
        throwsA(isA<SchemaException>()),
      );
    });
  });
}
