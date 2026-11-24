// Tests walk decoded JSON; dynamic access keeps the assertions readable.
// ignore_for_file: avoid_dynamic_calls, unnecessary_parenthesis

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sanitize_har.dart';

const _fixture = 'test/fixtures/synthetic.har';

/// Strings that exist only in the synthetic fixture and must never survive.
const _forbidden = [
  'FAKE_SESSION',
  'FAKE_CSRF',
  'FAKE_MID',
  'FAKE-IG-DID',
  'FAKELSD',
  'FAKEOH',
  'FAKEOE',
  'FAKESIG',
  'FAKEOHC',
  'fakeuser_alpha',
  'fakeuser_beta',
  'fake_viewer',
  'Fake Alpha',
  'Fake Beta',
  'Fake Viewer',
  'secret caption',
  'fake bio text',
  'fake.example.org',
  'FAKEcode00',
  'FAKEmaxid',
  '1111111111',
  '2222222222',
  '9999999999',
  '3333333333333333333',
  '3555555555555555555',
  '3444444444444444444',
];

String _shape(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return '{${keys.map((k) => '$k:${_shape(v[k])}').join(',')}}';
  }
  if (v is List) return '[${v.length}:${v.map(_shape).join(',')}]';
  if (v is String) return 's';
  return v.runtimeType.toString();
}

Map<String, dynamic> _har(List<Map<String, Object?>> entries) => {
  'log': {'entries': entries},
};

Map<String, Object?> _entry(
  String url,
  Object? body, {
  String mime = 'application/json',
}) => {
  'request': {'method': 'GET', 'url': url, 'headers': <Object?>[]},
  'response': {
    'status': 200,
    'content': {
      'mimeType': mime,
      'text': body is String ? body : jsonEncode(body),
    },
  },
};

void main() {
  late String har;
  late SanitizeOutcome outcome;

  setUpAll(() {
    har = File(_fixture).readAsStringSync();
    outcome = sanitizeHar(har);
  });

  Map<String, dynamic> body(String prefix) {
    final name = outcome.files.keys.firstWhere((k) => k.startsWith(prefix));
    return jsonDecode(outcome.files[name]!) as Map<String, dynamic>;
  }

  test('fixture sanitizes cleanly and writes the expected files', () {
    expect(outcome.ok, isTrue, reason: outcome.leaks.join('; '));
    expect(outcome.files.keys, containsAll(['summary.json', 'report.md']));
    // 5 instagram.com JSON requests; example.com, the HTML page and the
    // CDN image are not bodies.
    expect(outcome.files.keys.where((k) => k.startsWith('bodies/')).length, 5);
  });

  test('output contains no secrets, names, captions, IDs or signed URLs', () {
    for (final e in outcome.files.entries) {
      for (final s in _forbidden) {
        expect(e.value, isNot(contains(s)), reason: '${e.key} leaks $s');
      }
      expect(findLeaks(e.value), isEmpty, reason: e.key);
      expect(e.value, isNot(contains('Set-Cookie')), reason: e.key);
    }
  });

  test('every URL value becomes <url host=... path_shape=...>: no path '
      'segments, no query', () {
    final text = outcome.files['bodies/003_feed_user.json']!;
    expect(text, isNot(contains('http')));
    expect(text, isNot(contains('?')));
    final urls = RegExp('<url [^>]*>').allMatches(text).map((m) => m[0]!);
    expect(urls, isNotEmpty);
    for (final u in urls) {
      expect(
        u,
        matches(RegExp(r'^<url host=[a-z0-9.-]+ path_shape=\d+seg(\.\w+)?>$')),
      );
    }
    expect(text, contains('<url host=cdninstagram.com path_shape=3seg.jpg>'));
    expect(text, contains('<url host=cdninstagram.com path_shape=6seg.mp4>'));
  });

  test('JSON structure, types, dimensions and media fields are preserved', () {
    final original = jsonDecode(
      (jsonDecode(har)
              as Map)['log']['entries'][3]['response']['content']['text']
          as String,
    );
    final sanitized = body('bodies/003');
    expect(_shape(sanitized), _shape(original));

    final items = sanitized['items'] as List<dynamic>;
    expect(items, hasLength(4));
    expect(items.map((i) => (i as Map)['media_type']), [1, 2, 8, 2]);
    expect(items.map((i) => (i as Map)['product_type']), [
      'feed',
      'feed',
      'feed',
      'clips',
    ]);
    expect(items.first['taken_at'], 1700002000);
    final cand =
        (items.first['image_versions2'] as Map)['candidates'] as List<dynamic>;
    expect(cand.first['width'], 1080);
    expect(cand.first['height'], 1350);
    expect((items[2]['carousel_media'] as List<dynamic>), hasLength(2));
    expect(items[3]['video_versions'], isA<List<dynamic>>());
  });

  test('stories body keeps reels map shape, expiring_at and taken_at', () {
    final s = body('bodies/002');
    final reels = s['reels'] as Map<String, dynamic>;
    expect(reels.keys, ['user_1', 'user_2']);
    final it = (reels['user_1'] as Map)['items'] as List<dynamic>;
    expect(it, hasLength(2));
    expect(it.first['expiring_at'], 1700000100 + 86400);
    expect(it.first['video_versions'], hasLength(2));
    expect(it.last['video_versions'], isNull);
  });

  test('IDs and usernames are replaced consistently across files', () {
    final stories = body('bodies/002');
    final posts = body('bodies/003');
    final profile = body('bodies/001');
    final storyUser =
        ((stories['reels'] as Map)['user_1'] as Map)['user'] as Map;
    final postUser = posts['user'] as Map;
    final profUser = (profile['data'] as Map)['user'] as Map;
    for (final u in [storyUser, postUser, profUser]) {
      expect(u['pk'], 'user_1');
      expect(u['username'], '<str:14>');
      expect(u['full_name'], '<str:10>');
    }
    // Compound media id keeps both parts consistent.
    final firstStory =
        ((stories['reels'] as Map)['user_1'] as Map)['items'][0] as Map;
    expect(firstStory['id'], '${firstStory['pk']}_user_1');
    expect(firstStory['pk'], startsWith('media_'));
    // Distinct inputs stay distinct.
    final pks = (posts['items'] as List<dynamic>)
        .map((i) => (i as Map)['pk'])
        .toSet();
    expect(pks, hasLength(4));
    // Captions are default-deny placeholders carrying only the length.
    final caption =
        ((posts['items'] as List<dynamic>).first as Map)['caption'] as Map;
    expect(caption['text'], matches(RegExp(r'^<str:\d+>$')));
    // Viewer is a different user.
    final viewer = (body('bodies/004')['user'] as Map)['pk'];
    expect(viewer, isNot('user_1'));
    expect(viewer, startsWith('user_'));
  });

  test('integer IDs stay integers and map consistently', () {
    final out = sanitizeHar(
      jsonEncode(
        _har([
          _entry('https://www.instagram.com/api/v1/x/', {
            'user': {'pk': 12345678901, 'username': 'someone'},
            'owner': {'user_id': 12345678901, 'taken_at': 1700000000},
            'viewer': {'user_id': 99999999999},
          }),
        ]),
      ),
    );
    expect(out.ok, isTrue, reason: out.leaks.join());
    final j = jsonDecode(
      out.files.entries.firstWhere((e) => e.key.startsWith('bodies/')).value,
    ) as Map<String, dynamic>;
    final a = (j['user'] as Map)['pk'];
    expect(a, isA<int>());
    expect(a, greaterThanOrEqualTo(7000000000));
    expect((j['owner'] as Map)['user_id'], a);
    expect((j['owner'] as Map)['taken_at'], 1700000000);
    expect((j['viewer'] as Map)['user_id'], isNot(a));
    expect(out.files['report.md'], contains('int'));
  });

  test('summary keeps method, path and query keys but replaces values', () {
    final summary =
        jsonDecode(outcome.files['summary.json']!) as Map<String, dynamic>;
    final rows = (summary['requests'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(rows, hasLength(5));
    final ig1 = rows[0];
    expect(ig1['method'], 'GET');
    expect(ig1['path'], '/api/v1/users/web_profile_info/');
    expect(ig1['query'], {'username': '<v>'});
    final ig2 = rows[1];
    expect(ig2['query'], {
      'reel_ids': ['user_1', 'user_2'],
    });
    final ig5 = rows[2];
    expect(ig5['path'], '/api/v1/feed/user/user_1/');
    expect(ig5['query'], {'count': '12', 'max_id': '<v>'});
    expect(ig5['status'], 200);
    expect(ig5['responseSize'], greaterThan(0));
    // Header values dropped except the four allowed ones.
    final names = (ig5['requestHeaderNames'] as List<dynamic>).cast<String>();
    expect(names, containsAll(['cookie', 'x-csrftoken', 'user-agent']));
    expect((ig5['requestHeaders'] as Map).keys.toSet(), {
      'user-agent',
      'x-ig-app-id',
      'accept',
    });
    // POST body is never copied: only mime type, size, param names on the
    // allowlist, and the (public) doc_id.
    final post = rows[4]['postData'] as Map;
    expect(post['paramCount'], 3);
    expect(post['paramNames'], ['doc_id', 'variables']);
    expect(post['docId'], '1234567890123');
    expect(post['size'], greaterThan(0));
    expect(jsonEncode(rows[4]), isNot(contains('lsd')));
  });

  test('report.md detects candidates, unknown requests and media fields', () {
    final r = outcome.files['report.md']!;
    for (final id in ['IG-1', 'IG-2', 'IG-4', 'IG-5']) {
      expect(r, matches(RegExp('\\| $id \\|.*\\| yes \\|')));
    }
    expect(r, matches(RegExp(r'\| IG-3 \|.*\| no \|')));
    expect(r, contains('/graphql/query'));
    for (final f in [
      r'`$.reels.*.items[].expiring_at`',
      r'`$.items[].video_versions`',
      r'`$.items[].carousel_media`',
      r'`$.items[].image_versions2`',
      r'`$.items[].taken_at`',
      r'`$.items[].product_type`',
      r'`$.items[].video_dash_manifest`',
    ]) {
      expect(r, contains(f));
    }
    expect(r, contains('feed, clips'));
    // HTML page that embeds media markers is flagged without copying HTML.
    expect(r, contains('/stories/<seg>/'));
  });

  test('responses with no body are reported, not crashed on', () {
    final out = sanitizeHar(
      jsonEncode({
        'log': {
          'entries': [
            {
              'request': {
                'method': 'GET',
                'url': 'https://www.instagram.com/api/v1/x/',
                'headers': <Object?>[],
              },
              'response': {
                'status': 200,
                'content': {'mimeType': 'application/json', 'size': 10},
              },
            },
          ],
        },
      }),
    );
    expect(out.ok, isTrue);
    final rows =
        (jsonDecode(out.files['summary.json']!) as Map)['requests'] as List;
    expect((rows.single as Map)['bodyNote'], contains('no response body'));
    expect(out.files['report.md'], contains('no body in the HAR: 1'));
  });

  group('fails closed', () {
    // Every field the sanitizer copies is default-deny, so nothing in a real
    // HAR reaches the final scan with a secret. The scan is therefore tested
    // directly with planted output text (and through the CLI by injecting a
    // sanitizer that returns such text).
    const planted = '{"a": "a1b2c3d4e5f60718293a4b5c6d7e8f90"}';
    Map<String, String> files() => {
      'summary.json': '{}',
      'bodies/001_x.json': planted,
    };

    test('a token in any output file blocks all output', () {
      final out = finalizeOutputs(files());
      expect(out.ok, isFalse);
      expect(out.files, isEmpty);
      expect(out.leaks, ['bodies/001_x.json: long hex/base64 token']);
      expect(out.leaks.join(), isNot(contains('a1b2c3d4')));
    });

    test('clean output passes the final scan unchanged', () {
      final out = finalizeOutputs({'summary.json': '{"a": "<str:3>"}'});
      expect(out.ok, isTrue);
      expect(out.files, hasLength(1));
    });

    test('CLI exits 1 and writes nothing', () async {
      final tmp = Directory.systemTemp.createTempSync('har_test_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final input = File('${tmp.path}/in.har')
        ..writeAsStringSync(
          jsonEncode(
            _har([
              _entry('https://www.instagram.com/api/v1/x/', {'a': 1}),
            ]),
          ),
        );
      final outDir = '${tmp.path}/out';
      final err = StringBuffer();
      final code = await run(
        [input.path, outDir],
        out: StringBuffer(),
        err: err,
        sanitizer: (text, {keepKeys = const {}}) => finalizeOutputs(files()),
      );
      expect(code, 1);
      expect(Directory(outDir).existsSync(), isFalse);
      expect(err.toString(), contains('REFUSING TO WRITE'));
      expect(err.toString(), isNot(contains('a1b2c3d4')));
    });

    test('findLeaks flags cookies, signed URLs and long tokens', () {
      expect(findLeaks('x sessionid=abc123def; y'), isNotEmpty);
      expect(findLeaks('x sessionid%3Dabc123def; y'), isNotEmpty);
      expect(findLeaks('csrftoken=<redacted>'), isEmpty);
      expect(findLeaks('{"sessionid": "abc"}'), isNotEmpty);
      expect(findLeaks('{"sessionid": "<redacted>"}'), isEmpty);
      expect(findLeaks('https://a.example.net/x.jpg?oh=1&oe=2'), isNotEmpty);
      expect(findLeaks('https://a.example.net/x.jpg?<redacted>'), isNotEmpty);
      expect(findLeaks('https://a.example.net/x.jpg'), isEmpty);
      expect(findLeaks('see //a.example.net/x?_nc_sig=1'), isNotEmpty);
      expect(findLeaks('a' * 10), isEmpty);
      expect(findLeaks('0123456789abcdef0123456789abcdef'), isNotEmpty);
      expect(findLeaks('should_show_author_pog_for_tagged_users_x'), isEmpty);
      expect(findLeaks('Set-Cookie: a=b'), isNotEmpty);
    });
  });

  group('CLI', () {
    test('writes the output folder for the fixture and exits 0', () async {
      final tmp = Directory.systemTemp.createTempSync('har_test_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final out = StringBuffer();
      final code = await run(
        [_fixture, '${tmp.path}/out'],
        out: out,
        err: StringBuffer(),
      );
      expect(code, 0);
      expect(File('${tmp.path}/out/report.md').existsSync(), isTrue);
      expect(File('${tmp.path}/out/summary.json').existsSync(), isTrue);
      expect(Directory('${tmp.path}/out/bodies').listSync(), hasLength(5));
    });

    test('bad usage and bad input exit 2', () async {
      expect(await run([], out: StringBuffer(), err: StringBuffer()), 2);
      expect(
        await run(
          ['/nope.har', '/tmp/x'],
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        2,
      );
      final tmp = Directory.systemTemp.createTempSync('har_test_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final f = File('${tmp.path}/a.har')..writeAsStringSync('{"x":1}');
      expect(
        await run(
          [f.path, '${tmp.path}/o'],
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        2,
      );
    });
  });
}
