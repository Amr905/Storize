// QA round 3: object keys, doc_id/query_hash smuggling, URL host placeholders,
// and usefulness of the sanitized structure. All data is FAKE.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sanitize_har.dart';

const _u = 'https://www.instagram.com/api/v1/friendships/show_many/';

String _har(Object? body, {String url = _u}) => jsonEncode({
  'log': {
    'entries': [
      {
        'request': {'method': 'GET', 'url': url, 'headers': <Object?>[]},
        'response': {
          'status': 200,
          'content': {'mimeType': 'application/json', 'text': jsonEncode(body)},
        },
      },
    ],
  },
});

/// Output text, or null when the run failed closed.
String? _out(Object? body, {String url = _u}) {
  final o = sanitizeHar(_har(body, url: url));
  return o.ok ? o.files.values.join('\n') : null;
}

void keyNoLeak(String name, Object? body, {String? skip, String? url}) {
  test(name, skip: skip, () {
    final out = _out(body, url: url ?? _u);
    if (out != null) expect(out.toLowerCase(), isNot(contains('zzfake')));
  });
}

void main() {
  group('object keys that must not survive (pass today)', () {
    keyNoLeak('friendship_statuses keyed by numeric id', {
      'friendship_statuses': {
        '1234567890': {'following': true},
      },
    });
    keyNoLeak('reels keyed by highlight:<id>', {
      'reels': {
        'highlight:17900000001234567': {'items': <Object?>[]},
      },
    });
    keyNoLeak('keyed by email', {
      'm': {
        'zzfake@example.com': {'a': 1},
      },
    });
    keyNoLeak('keyed by phone (fail closed or redacted)', {
      'm': {'+201000000000': 1},
    });
    keyNoLeak('keyed by URL with query (fail closed or redacted)', {
      'm': {'https://x.cdninstagram.com/a.jpg?oh=zzfakeoh': 1},
    });
    keyNoLeak('key containing sessionid=', {'sessionid=zzfake1': 1});
    keyNoLeak('key containing sessionid%3D', {'a sessionid%3Dzzfake1 b': 1});
    keyNoLeak('key containing JSON with sessionid', {
      '{"sessionid":"zzfake1"}': 1,
    });
    keyNoLeak('key with spaces (display name)', {'Zzfake Real Name': 1});
    keyNoLeak('unicode username key', {'zzfake_用户': 1});
    keyNoLeak('usernames as array values', {
      'users': ['zzfakeuser'],
    });
  });

  group('QA-10 username-like object keys', () {
    keyNoLeak('users keyed by username', {
      'users': {
        'zzfake_nour.k': {'pk': '1234567890'},
      },
    });
    keyNoLeak('friendship_statuses keyed by username', {
      'friendship_statuses': {
        'zzfake_someone': {'following': true},
      },
    });
    keyNoLeak('reels keyed by username', {
      'reels': {
        'zzfake_reeluser': {'items': <Object?>[]},
      },
    });
    keyNoLeak('uppercase username key', {'ZZFAKE_Nour': 1});
    keyNoLeak('nested unknown keys', {
      'a': {
        'zzfakeinner': {'zzfakeinner2': 1},
      },
    });
    keyNoLeak('URL as key (host+path, no query)', {
      'm': {
        'https://linktr.ee/zzfake': {'a': 1},
      },
    });
  });

  group('doc_id / query_hash exemption', () {
    const g = 'https://www.instagram.com/graphql/query/';
    keyNoLeak(
      'long mixed-case token in doc_id',
      {'a': 1},
      url:
          '$g?doc_id=ZZFAKEabcdefghijKLMNOPQRSTUVWXYZ0123456789'
          '&query_hash=sessionid%3Dzzfake5',
    );
    keyNoLeak('cookie-like doc_id / query_hash', {
      'a': 1,
    }, url: '$g?doc_id=sessionid=zzfake6&query_hash=csrftoken%3Dzzfake7');
    keyNoLeak('doc_id with an email', {
      'a': 1,
    }, url: '$g?doc_id=zzfake%40x.com');
    test('QA-11 doc_id/query_hash must be digits or hex only', () {
      final out = _out({
        'a': 1,
      }, url: '$g?doc_id=zzfakeuser&query_hash=zzfake2');
      if (out != null) expect(out.toLowerCase(), isNot(contains('zzfake')));
    });
  });

  group('URL host placeholder cannot carry identity', () {
    test(
      'subdomain, userinfo, port, IDN, uppercase, IP all become external',
      () {
        final out = _out({
          'external_url': 'https://zzfakename.linktr.ee/x',
          'bio_links': [
            {'url': 'https://zzfakename.linktr.ee/'},
          ],
          'a': 'https://zzfakeuser:pw@host.com/',
          'b': 'http://zzfake.tumblr.com',
          'c': '//zzfake.carrd.co/',
          'd': 'https://ZZFakeName.LinkTree.ee/',
          'e': 'http://192.168.1.77:3000/zzfake',
          'f': 'https://zzfake用户.example.com/',
          'g': 'see zzfake.bsky.social and https://zzfake.example.org/x ok',
        })!;
        expect(out.toLowerCase(), isNot(contains('zzfake')));
        expect(out, isNot(contains('192.168')));
        expect(out, contains('<url host=external'));
      },
    );
  });

  group('sanitized structure is still useful', () {
    late Map<String, dynamic> story;
    late String post;
    setUpAll(() {
      // Fixture run through the library, the same way the CLI does.
      final har = _syntheticHar();
      final o = sanitizeHar(har);
      expect(o.ok, isTrue, reason: '${o.leaks}');
      final f = o.files.keys.firstWhere((k) => k.contains('reels_media'));
      story = jsonDecode(o.files[f]!) as Map<String, dynamic>;
      post = o.files.entries
          .firstWhere((e) => e.key.contains('feed_user'))
          .value;
    });

    test('story keeps media_type, product_type, taken_at, expiring_at', () {
      final reels = story['reels'] as Map<String, dynamic>;
      final items = (reels.values.first as Map)['items'] as List;
      final video = items.first as Map;
      expect(video['media_type'], 2);
      expect(video['product_type'], 'story');
      expect(video['taken_at'], isA<int>());
      expect(video['expiring_at'], isA<int>());
      expect(video['has_audio'], isA<bool>());
    });

    test('video_versions[] and image candidates keep count and dimensions', () {
      final reels = story['reels'] as Map<String, dynamic>;
      final video = ((reels.values.first as Map)['items'] as List).first as Map;
      final vv = video['video_versions'] as List;
      expect(vv, hasLength(2));
      expect((vv.first as Map)['width'], 720);
      expect((vv.first as Map)['height'], 1280);
      expect(
        (video['image_versions2'] as Map)['candidates'] as List,
        hasLength(2),
      );
      expect('${(vv.first as Map)['url']}', startsWith('<url host='));
    });

    test('carousel_media is present in the posts body', () {
      expect(post, contains('carousel_media'));
    });
  });
}

String _syntheticHar() =>
    File('test/fixtures/synthetic.har').readAsStringSync();
