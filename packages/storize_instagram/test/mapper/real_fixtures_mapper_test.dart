// The mappers against the sanitized real capture (T-002). Placeholders only:
// no names, IDs or URLs. Expected values are read from the raw fixture JSON
// by independent code, so a mapper bug cannot hide behind itself.
// ignore_for_file: avoid_dynamic_calls, lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _mapper = EnvelopeMapper();
const _media = MediaMapper();

/// The largest candidate area of a raw `image_versions2` object.
int _maxArea(dynamic image) {
  var best = 0;
  for (final c in image['candidates'] as List<dynamic>) {
    final area = (c['width'] as int) * (c['height'] as int);
    if (area > best) best = area;
  }
  return best;
}

void main() {
  group('story reel (real capture)', () {
    final body = loadReal('story', '003_graphql.json');
    final reels = _mapper.graphqlStories(nodeOf(body));

    test('one reel keyed by the owner id, with its change signal', () {
      expect(reels.keys, ['user_1']);
      final reel = reels['user_1']!;
      expect(reel.items, hasLength(1));
      expect(
        reel.latestReelMedia,
        DateTime.fromMillisecondsSinceEpoch(1795115924 * 1000, isUtc: true),
      );
      expect(reel.items.single.postedAt, reel.latestReelMedia);
    });

    test('AC2 story item: video, expiring_at, 24 h, no shortcode', () {
      final item = reels['user_1']!.items.single;
      expect(item.kind, ContentKind.story);
      expect(item.remoteId, 'media_16');
      expect(
        item.expiresAt!.difference(item.postedAt),
        const Duration(hours: 24),
      );
      expect(item.postType, isNull);
      expect(item.closeFriends, isFalse);
      expect(item.extras, isEmpty);
      final slide = item.slides.single;
      expect(slide.index, 0);
      expect(slide.type, MediaType.video);
      expect(slide.duration, const Duration(seconds: 15));
    });

    test('AC3 story video: no sizes on the versions, so the first is used '
        'and the size comes from original_width/height', () {
      final slide = reels['user_1']!.items.single.slides.single;
      expect(slide.width, 480);
      expect(slide.height, 854);
      expect(slide.url, contains('.mp4'));
    });
  });

  group('timeline (real capture)', () {
    final body = loadReal('profile', '007_graphql.json');
    final timeline = _mapper.graphqlTimeline(nodeOf(body));
    final raw =
        ((body! as Map)['data']
                as Map)['xdt_api__v1__feed__user_timeline_graphql_connection']['edges']
            as List<dynamic>;

    test('12 entries, listed in Instagram order (pinned first)', () {
      expect(timeline.entries, hasLength(12));
      expect(timeline.entries.first.pinned, isTrue);
      expect(timeline.entries.map((e) => e.pk).toSet(), hasLength(12));
      expect(timeline.viewerId, 'user_3');
    });

    test('AC8 collab: the first node is authored by another account but '
        'belongs to the tracked user through coauthor_producers', () {
      final first = timeline.entries.first;
      expect(first.authorIds, {'user_2'});
      expect(first.coauthorIds, contains('user_1'));
      expect(first.belongsTo('user_1'), isTrue);
      expect(first.isCollabOf('user_1'), isTrue);
      expect(first.belongsTo('user_9'), isFalse);
      final post = _media.post(first.node, pinned: first.pinned, collab: true);
      expect(post.extras, {'pinned': true, 'collab': true});
    });

    test('AC8 pinned: pinned posts are not the newest by time', () {
      final newest = timeline.entries.reduce(
        (a, b) => a.takenAt.isAfter(b.takenAt) ? a : b,
      );
      expect(newest.pinned, isFalse);
      expect(timeline.entries.where((e) => e.pinned), hasLength(3));
      expect(
        timeline.entries.first.takenAt.isBefore(newest.takenAt),
        isTrue,
        reason: 'edges[0] is pinned and older than the newest post',
      );
    });

    test('AC8 errors[] next to complete data does not stop the mapping', () {
      expect((body as Map)['errors'], isNotEmpty);
      for (final e in timeline.entries) {
        expect(() => _media.post(e.node), returnsNormally);
      }
    });

    test('AC2 every node maps; types follow media_type and product_type', () {
      final posts = [for (final e in timeline.entries) _media.post(e.node)];
      for (var i = 0; i < posts.length; i++) {
        final node = raw[i]['node'];
        final p = posts[i];
        expect(p.kind, ContentKind.post);
        expect(p.remoteId, node['pk']);
        expect(p.shortcode, isNotEmpty);
        expect(
          p.postedAt,
          DateTime.fromMillisecondsSinceEpoch(
            (node['taken_at'] as int) * 1000,
            isUtc: true,
          ),
        );
        expect(p.expiresAt, isNull);
        final expected = switch (node['media_type'] as int) {
          1 => PostType.photo,
          8 => PostType.carousel,
          _ => node['product_type'] == 'clips' ? PostType.reel : PostType.video,
        };
        expect(p.postType, expected);
        expect(p.caption, node['caption'] == null ? isNull : isNotNull);
      }
      expect(posts.map((p) => p.postType).toSet(), {
        PostType.photo,
        PostType.reel,
        PostType.carousel,
      });
    });

    test('AC3 photos: the largest candidate of the timeline response', () {
      for (var i = 0; i < raw.length; i++) {
        final node = raw[i]['node'];
        if (node['media_type'] != 1) continue;
        final slide = _media.post(timeline.entries[i].node).slides.single;
        expect(slide.type, MediaType.photo);
        expect(slide.width * slide.height, _maxArea(node['image_versions2']));
        expect(slide.width, node['original_width']);
      }
    });

    test('AC3 reels: the largest progressive version, with its size', () {
      for (var i = 0; i < raw.length; i++) {
        final node = raw[i]['node'];
        if (node['product_type'] != 'clips') continue;
        final slide = _media.post(timeline.entries[i].node).slides.single;
        var best = 0;
        for (final v in node['video_versions'] as List<dynamic>) {
          final area = (v['width'] as int) * (v['height'] as int);
          if (area > best) best = area;
        }
        expect(slide.type, MediaType.video);
        expect(slide.width * slide.height, best);
        expect(slide.url, contains('.mp4'));
        expect(
          slide.duration,
          isNull,
          reason: 'timeline nodes have no duration',
        );
      }
    });

    test('AC2 carousel: slides in order with their own index', () {
      final i = raw.indexWhere((e) => e['node']['media_type'] == 8);
      final children = raw[i]['node']['carousel_media'] as List<dynamic>;
      final post = _media.post(timeline.entries[i].node);
      expect(post.slides, hasLength(children.length));
      for (var s = 0; s < children.length; s++) {
        expect(post.slides[s].index, s);
        expect(
          post.slides[s].width * post.slides[s].height,
          _maxArea(children[s]['image_versions2']),
        );
      }
    });
  });

  group('media/<pk>/info (real capture)', () {
    test('photo: maps, but the image is the capped 720 px rendition', () {
      final body = loadReal('post_photo', '003_media_info.json');
      final item = nodeOf(body)['items'].list.first;
      final post = _media.post(item);
      expect(post.postType, PostType.photo);
      expect(post.slides.single.width, lessThanOrEqualTo(720));
    });

    test('carousel: children have taken_at, the parent time is used', () {
      final body = loadReal('post_carousel', '002_media_info.json');
      final item = nodeOf(body)['items'].list.first;
      final post = _media.post(item);
      expect(post.postType, PostType.carousel);
      expect(post.slides.map((s) => s.index), [0, 1]);
      expect(post.postedAt, item['taken_at'].unixTime);
    });

    test('reel: post_type REEL with a duration', () {
      final body = loadReal('reel', '003_media_info.json');
      final item = nodeOf(body)['items'].list.first;
      final post = _media.post(item);
      expect(post.postType, PostType.reel);
      final slide = post.slides.single;
      expect(slide.type, MediaType.video);
      expect(slide.duration, isNotNull);
      expect(slide.width, 720);
      expect(slide.height, 1280);
    });
  });

  group('profile (real capture)', () {
    test('user fields and the cheap signals', () {
      final body = loadReal('profile', '004_graphql.json');
      final (profile, viewer) = _mapper.graphqlProfile(nodeOf(body));
      expect(viewer, 'user_3');
      final user = profile!.user;
      expect(user.remoteUserId, 'user_1');
      expect(user.isPrivate, isFalse);
      expect(user.followedByViewer, isTrue);
      expect(user.blockedByViewer, isFalse);
      expect(user.username, isNotEmpty);
      expect(profile.mediaCount, 79);
      expect(
        profile.latestReelMedia,
        DateTime.fromMillisecondsSinceEpoch(1795115924 * 1000, isUtc: true),
      );
    });
  });
}
