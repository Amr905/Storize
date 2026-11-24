// Shape test for the sanitized real captures (T-002, 2026-11-20).
//
// The fixtures under test/fixtures/real/ are sanitizer output of a real
// capture: placeholders only, no raw names, IDs or URLs. This test pins the
// JSON paths documented in docs/03-specs/INSTAGRAM_EXTRACTION.md, so a
// fixture refresh or a schema change that moves a path fails loudly.
//
// Tests walk decoded JSON; dynamic access keeps the assertions readable.
// ignore_for_file: avoid_dynamic_calls, lines_longer_than_80_chars

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _root = 'test/fixtures/real';
const _stories = 'data.xdt_api__v1__feed__reels_media';
const _timeline = 'data.xdt_api__v1__feed__user_timeline_graphql_connection';

dynamic _load(String name, String body) =>
    jsonDecode(File('$_root/$name/bodies/$body').readAsStringSync());

/// All values at a dotted path. `[]` after a name fans out over a list.
/// Missing keys yield no values (never an exception).
List<dynamic> _at(dynamic json, String path) {
  var cur = <dynamic>[json];
  for (final raw in path.split('.')) {
    final fan = raw.endsWith('[]');
    final key = fan ? raw.substring(0, raw.length - 2) : raw;
    final next = <dynamic>[];
    for (final c in cur) {
      if (c is Map && c.containsKey(key)) {
        final v = c[key];
        if (fan) {
          if (v is List) next.addAll(v);
        } else {
          next.add(v);
        }
      }
    }
    cur = next;
  }
  return cur;
}

/// Every parent at `parents` must have a non-null value at each of `subs`.
void _expectAll(dynamic json, String parents, List<String> subs) {
  final ps = _at(json, parents);
  expect(ps, isNotEmpty, reason: 'no values at $parents');
  for (final s in subs) {
    final n = ps.where((p) => _at(p, s).isNotEmpty && _at(p, s).first != null);
    expect(n.length, ps.length, reason: '$parents.$s missing on some entries');
  }
}

void _expectImageCandidates(dynamic item) {
  final c = _at(item, 'image_versions2.candidates[]');
  expect(c, isNotEmpty);
  for (final x in c) {
    expect(x['url'], isA<String>());
    expect(x['width'], isA<int>());
    expect(x['height'], isA<int>());
  }
}

void main() {
  group('story reel page (PolarisStoriesV3ReelPageStandaloneQuery)', () {
    final body = _load('story', '003_graphql.json');

    test('reel and item paths exist with the documented types', () {
      _expectAll(body, '$_stories.reels_media[]', [
        'id',
        'reel_type',
        'items',
        'user.id',
        'user.pk',
        'latest_reel_media',
        'seen',
      ]);
      expect(_at(body, '$_stories.reels_media[].reel_type'), ['user_reel']);
      _expectAll(body, '$_stories.reels_media[].items[]', [
        'pk',
        'id',
        'media_type',
        'product_type',
        'taken_at',
        'expiring_at',
        'image_versions2.candidates',
        'original_width',
        'original_height',
        'user.pk',
        'code',
      ]);
    });

    test('items are stories that expire 24 h after taken_at', () {
      final items = _at(body, '$_stories.reels_media[].items[]');
      for (final i in items) {
        expect(i['product_type'], 'story');
        expect(i['media_type'], anyOf(1, 2));
        expect(i['expiring_at'] - i['taken_at'], 86400);
        _expectImageCandidates(i);
      }
    });

    test('video stories carry progressive versions, audio flag and DASH', () {
      final videos = _at(
        body,
        '$_stories.reels_media[].items[]',
      ).where((i) => i['media_type'] == 2).toList();
      expect(videos, isNotEmpty, reason: 'fixture must contain a video story');
      for (final v in videos) {
        final vv = _at(v, 'video_versions[]');
        expect(vv, isNotEmpty);
        for (final x in vv) {
          expect(x['type'], isA<int>());
          expect(x['url'], isA<String>());
          // Observed: story video_versions have no width/height.
          expect(x.containsKey('width'), isFalse);
        }
        expect(v['has_audio'], isA<bool>());
        expect(v['video_duration'], isA<num>());
        expect(v['video_dash_manifest'], isA<String>());
      }
    });

    test('ids link: reel id is the owner id, item id is pk_owner', () {
      final reel = _at(body, '$_stories.reels_media[]').first;
      expect(reel['id'], reel['user']['pk']);
      for (final i in _at(reel, 'items[]')) {
        expect(i['id'], '${i['pk']}_${i['user']['pk']}');
        expect(i['user']['pk'], reel['user']['pk']);
      }
    });

    test('viewer id is present on the response (session evidence)', () {
      expect(_at(body, 'data.xdt_viewer.user.id').single, isA<String>());
    });
  });

  group('profile page content (PolarisProfilePageContentQuery)', () {
    final body = _load('profile', '004_graphql.json');

    test('user root gives id, username lookup fields and counters', () {
      _expectAll(body, 'data.user', [
        'id',
        'pk',
        'username',
        'is_private',
        'media_count',
        'latest_reel_media',
        'friendship_status.following',
      ]);
      final u = _at(body, 'data.user').single;
      expect(u['id'], u['pk']);
      expect(u['is_private'], isA<bool>());
      expect(u['media_count'], isA<int>());
      expect(u['latest_reel_media'], isA<int>());
      expect(u['friendship_status']['following'], isA<bool>());
    });

    test('viewer root carries the logged-in user id (session evidence)', () {
      expect(_at(body, 'data.viewer.user.id').single, isA<String>());
      expect(_at(body, 'data.viewer.user.pk').single, isA<String>());
    });
  });

  group('profile posts (PolarisProfilePostsQuery)', () {
    final body = _load('profile', '007_graphql.json');
    final nodes = _at(body, '$_timeline.edges[].node');

    test('connection, paging and viewer paths exist', () {
      expect(nodes, isNotEmpty);
      expect(
        _at(body, '$_timeline.page_info.end_cursor').single,
        isA<String>(),
      );
      expect(
        _at(body, '$_timeline.page_info.has_next_page').single,
        isA<bool>(),
      );
      expect(_at(body, 'data.xdt_viewer.user.id').single, isA<String>());
    });

    test('every node has the common media fields', () {
      _expectAll(body, '$_timeline.edges[].node', [
        'code',
        'pk',
        'id',
        'taken_at',
        'media_type',
        'product_type',
        'user.pk',
        'owner_id.pk',
        'original_width',
        'original_height',
        'image_versions2.candidates',
      ]);
      for (final n in nodes) {
        expect(n['media_type'], anyOf(1, 2, 8));
        expect(n['product_type'], anyOf('feed', 'clips', 'carousel_container'));
        _expectImageCandidates(n);
      }
    });

    test('video nodes have sized progressive versions and an audio flag', () {
      final videos = nodes.where((n) => n['media_type'] == 2).toList();
      expect(videos, isNotEmpty);
      for (final v in videos) {
        expect(v['product_type'], 'clips');
        final vv = _at(v, 'video_versions[]');
        expect(vv, isNotEmpty);
        for (final x in vv) {
          expect(x['type'], isA<int>());
          expect(x['url'], isA<String>());
          expect(x['width'], isA<int>());
          expect(x['height'], isA<int>());
        }
        expect(v['has_audio'], isA<bool>());
      }
    });

    test('carousel nodes list children with their own media', () {
      final cars = nodes.where((n) => n['media_type'] == 8).toList();
      expect(cars, isNotEmpty, reason: 'fixture must contain a carousel');
      for (final c in cars) {
        final kids = _at(c, 'carousel_media[]');
        expect(kids, isNotEmpty);
        for (final k in kids) {
          expect(k['media_type'], anyOf(1, 2));
          _expectImageCandidates(k);
        }
      }
    });

    test('pinned posts are marked and need not be in date order', () {
      final pinned = nodes.where(
        (n) =>
            n['timeline_pinned_user_ids'] is List &&
            (n['timeline_pinned_user_ids'] as List).isNotEmpty,
      );
      expect(pinned, isNotEmpty, reason: 'fixture must contain a pinned post');
    });

    test('collab node: coauthor_producers present, node.user may differ', () {
      final collab = nodes.where(
        (n) =>
            n['coauthor_producers'] is List &&
            (n['coauthor_producers'] as List).isNotEmpty,
      );
      expect(collab, isNotEmpty);
    });

    test('partial errors[] sit beside a complete data object', () {
      final errs = body['errors'];
      expect(errs, isA<List<dynamic>>());
      expect(body['data'], isA<Map<String, dynamic>>());
      expect(nodes.length, greaterThan(0));
    });
  });

  group('single media (GET /api/v1/media/<id>/info/)', () {
    for (final f in [
      ('post_photo', '003_media_info.json'),
      ('post_carousel', '002_media_info.json'),
      ('reel', '003_media_info.json'),
    ]) {
      test('${f.$1}: envelope and item paths', () {
        final body = _load(f.$1, f.$2);
        expect(body['status'], 'ok');
        expect(body['num_results'], 1);
        expect(body['more_available'], isA<bool>());
        expect(body['items'], hasLength(1));
        _expectAll(body, 'items[]', [
          'id',
          'pk',
          'code',
          'media_type',
          'product_type',
          'taken_at',
          'user.pk',
          'owner.pk',
          'original_width',
          'original_height',
          'image_versions2.candidates',
        ]);
        final i = body['items'][0];
        expect(i['user']['pk'], i['owner']['pk']);
        expect(i['id'], '${i['pk']}_${i['owner']['pk']}');
        _expectImageCandidates(i);
      });
    }

    test('photo: media_type 1, feed', () {
      final i = _load('post_photo', '003_media_info.json')['items'][0];
      expect(i['media_type'], 1);
      expect(i['product_type'], 'feed');
      expect(i.containsKey('video_versions'), isFalse);
    });

    test('carousel: ordered children, count matches', () {
      final i = _load('post_carousel', '002_media_info.json')['items'][0];
      expect(i['media_type'], 8);
      expect(i['product_type'], 'carousel_container');
      final kids = _at(i, 'carousel_media[]');
      expect(kids.length, i['carousel_media_count']);
      for (final k in kids) {
        expect(k['media_type'], anyOf(1, 2));
        // Real value is 'carousel_item'; the sanitizer redacts it (not in its list).
        expect(k['product_type'], isA<String>());
        _expectImageCandidates(k);
      }
    });

    test('reel: video_versions, audio flag, duration, DASH manifest', () {
      final i = _load('reel', '003_media_info.json')['items'][0];
      expect(i['media_type'], 2);
      expect(i['product_type'], 'clips');
      expect(i['has_audio'], isA<bool>());
      expect(i['video_duration'], isA<num>());
      expect(i['video_dash_manifest'], isA<String>());
      final vv = _at(i, 'video_versions[]');
      expect(vv, isNotEmpty);
      for (final x in vv) {
        expect(x['type'], isA<int>());
        expect(x['url'], isA<String>());
        expect(x['width'], isA<int>());
        expect(x['height'], isA<int>());
      }
    });
  });

  group('helper and leak guard (failure paths)', () {
    test('_at returns nothing for a removed path, so _expectAll fails', () {
      final body = jsonDecode(jsonEncode(_load('story', '003_graphql.json')));
      (_at(body, '$_stories.reels_media[].items[]').first as Map).remove(
        'expiring_at',
      );
      expect(
        () => _expectAll(body, '$_stories.reels_media[].items[]', [
          'expiring_at',
        ]),
        throwsA(isA<TestFailure>()),
      );
      expect(_at(body, 'data.no_such.path[]'), isEmpty);
    });

    test('fixtures hold no URLs, cookies or doc_id values', () {
      final files = Directory(_root)
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(files, isNotEmpty);
      final bad = <RegExp>[
        RegExp('https?://'),
        RegExp('_nc_'),
        RegExp('sessionid', caseSensitive: false),
        RegExp('csrftoken', caseSensitive: false),
        RegExp('ds_user_id'),
        RegExp('"docId"'),
        RegExp(r'doc_id[^<\n]{0,8}\d{6,}'),
      ];
      for (final f in files) {
        final t = f.readAsStringSync();
        for (final r in bad) {
          expect(r.hasMatch(t), isFalse, reason: '${f.path} matches $r');
        }
      }
    });

    test('each real fixture folder stays under 300 KB', () {
      for (final d in Directory(_root).listSync().whereType<Directory>()) {
        final size = d
            .listSync(recursive: true)
            .whereType<File>()
            .fold<int>(0, (s, f) => s + f.lengthSync());
        expect(size, lessThan(300 * 1024), reason: d.path);
      }
    });
  });
}
