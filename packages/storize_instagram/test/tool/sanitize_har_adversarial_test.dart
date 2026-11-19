// QA adversarial tests for tool/sanitize_har.dart (T-002 prep).
// All data is FAKE and synthetic. Markers contain "zzfake" or are fake IDs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sanitize_har.dart';

const _tool = 'tool/sanitize_har.dart';
const _fx = 'test/tool/fixtures';
const _syn = 'test/fixtures/synthetic.har';

/// Strings that exist only in the fake fixtures. None may reach the output.
const _markers = [
  'zzfake',
  '5151515151',
  '5252525252',
  '4141414141',
  '3141592653589793',
  '用户',
  'üñí',
  '名前',
  'секрет',
  'Ελένη',
  'عربى',
  '😀',
];

String _allOutput(Directory d) => [
  for (final f in d.listSync(recursive: true).whereType<File>())
    '${f.path}\n${f.readAsStringSync()}',
].join('\n');

/// Runs the CLI exactly as the capture guide says (`dart <file>`).
Future<ProcessResult> _cli(String har, Directory out) =>
    Process.run('dart', [_tool, har, out.path]);

const _fixtures = [
  'adv_cookies',
  'adv_body_sessionid',
  'adv_nested_json',
  'adv_post_body',
  'adv_usernames',
  'adv_auth_ids',
  'adv_base64',
  'adv_html',
  'adv_unicode',
  'adv_extra',
];

String _har(Object? body, {String url = _u}) => jsonEncode({
  'log': {
    'entries': [
      {
        'request': {'method': 'GET', 'url': url, 'headers': <Object?>[]},
        'response': {
          'status': 200,
          'content': {
            'mimeType': 'application/json',
            'text': body is String ? body : jsonEncode(body),
          },
        },
      },
    ],
  },
});

const _u =
    'https://www.instagram.com/api/v1/feed/reels_media/?reel_ids=4141414141';

/// Realistic-length FAKE session value.
const _sid = '5252525252%3AZZFAKEaBcDeFgHiJk%3A27%3AZZFAKEaBcDeFgHiJkLmNo';

/// Sanitizes in-process; returns output text, or null if it failed closed.
String? _out(String har) {
  final o = sanitizeHar(har);
  return o.ok ? o.files.values.join('\n') : null;
}

void main() {
  late Directory tmp;
  setUpAll(() => tmp = Directory.systemTemp.createTempSync('san_adv_'));
  tearDownAll(() => tmp.deleteSync(recursive: true));

  group('CLI: every adversarial fixture sanitizes with zero leaks or fails '
      'closed', () {
    for (final name in _fixtures) {
      test(name, () async {
        final out = Directory('${tmp.path}/$name');
        final r = await _cli('$_fx/$name.har', out);
        if (r.exitCode == 0) {
          final text = _allOutput(out).toLowerCase();
          for (final m in _markers) {
            expect(
              text.contains(m.toLowerCase()),
              isFalse,
              reason: '$name leaked marker "$m"',
            );
          }
          expect(findLeaks(_allOutput(out)), isEmpty);
        } else {
          expect(r.exitCode, 1, reason: '${r.stderr}');
          expect(
            out.existsSync() && out.listSync().isNotEmpty,
            isFalse,
            reason: 'failed closed but wrote files',
          );
          expect('${r.stderr}${r.stdout}', isNot(contains('zzfake')));
          expect(
            '${r.stderr}${r.stdout}'.toLowerCase(),
            isNot(contains('zzfake')),
            reason: 'refusal message must not echo the secret',
          );
        }
      });
    }
  });

  test(
    'cookies in cookies[], Cookie/cookie/COOKIE, Set-Cookie are dropped',
    () {
      final out = _out(File('$_fx/adv_cookies.har').readAsStringSync())!;
      expect(out.toLowerCase(), isNot(contains('zzfake')));
      expect(out, isNot(contains('5151515151')));
      // header NAMES are kept (useful), values are not
      expect(out, contains('cookie'));
    },
  );

  test('QA-8 POST bodies / query params named csrftoken or sessionid are '
      'not copied, so the HAR is no longer refused', () {
    for (final f in ['adv_post_body', 'adv_extra']) {
      final out = _out(File('$_fx/$f.har').readAsStringSync());
      expect(out, isNotNull, reason: f);
      expect(out!.toLowerCase(), isNot(contains('zzfake')), reason: f);
    }
  });

  test('default-deny: every adversarial fixture and synthetic.har run through '
      'the CLI exit 0 and pass the hardened scanner (raw, URL-decoded, '
      'JSON-unescaped)', () async {
    for (final name in [..._fixtures.map((n) => '$_fx/$n.har'), _syn]) {
      final out = Directory('${tmp.path}/all_${name.hashCode}');
      final r = await _cli(name, out);
      expect(r.exitCode, 0, reason: '$name: ${r.stderr}');
      final text = _allOutput(out);
      expect(findLeaks(text), isEmpty, reason: name);
      expect(findLeaks(Uri.decodeFull(text)), isEmpty, reason: name);
      expect(text.toLowerCase(), isNot(contains('zzfake')), reason: name);
      expect(text, isNot(contains('http')), reason: '$name: no raw URLs');
    }
  });

  test('every string value in a body is a <str:N> / <url ...> / <dash:N> '
      'placeholder unless its key is on the structural allowlist', () {
    final o = sanitizeHar(
      _har({
        'text': 'free text',
        'user': {'username': 'zzfakeu', 'full_name': 'ZZFAKE N'},
        'items': ['x', 'y'],
        'product_type': 'clips',
        'status': 'ok',
        'type': 'has space',
        'mime_type': 'video/mp4',
        'video_dash_manifest': '<MPD>zzfake</MPD>',
        'owner': {'url': 'https://scontent-x.cdninstagram.com/a/b/c.jpg?oh=1'},
      }),
    );
    final j = jsonDecode(
      o.files.entries.firstWhere((e) => e.key.startsWith('bodies/')).value,
    ) as Map<String, dynamic>;
    expect(j['text'], '<str:9>');
    expect((j['user'] as Map)['username'], '<str:7>');
    expect(j['items'], ['<str:1>', '<str:1>']);
    expect(j['product_type'], 'clips');
    expect(j['status'], 'ok');
    expect(j['type'], '<str:9>', reason: 'allowlisted key, bad pattern');
    expect(j['mime_type'], 'video/mp4');
    expect(j['video_dash_manifest'], '<dash:17>');
    expect(
      (j['owner'] as Map)['url'],
      '<url host=cdninstagram.com path_shape=3seg.jpg>',
    );
  });

  test('known keys are kept and array lengths/nesting are unchanged', () {
    final body = {
      'items': [
        {
          'code': 'x',
          'candidates': [1, 2, 3],
        },
        {'code': 'y', 'candidates': <int>[]},
      ],
      'user': {'status': null},
    };
    final o = sanitizeHar(_har(body));
    final j = jsonDecode(
      o.files.entries.firstWhere((e) => e.key.startsWith('bodies/')).value,
    ) as Map<String, dynamic>;
    final items = j['items'] as List;
    expect((items[0] as Map).keys, ['code', 'candidates']);
    expect((items[0] as Map)['candidates'] as List, [1, 2, 3]);
    expect((items[1] as Map)['candidates'] as List, isEmpty);
    expect((j['user'] as Map).containsKey('status'), isTrue);
  });

  test('QA-1 variants: URL-encoded name inside a KEY and double-encoded', () {
    final o = sanitizeHar(
      _har({
        'sessionid%3DZZFAKEkey1': 1,
      }),
    );
    // QA-10: the unknown key is replaced by key_N, so nothing leaks.
    expect(o.ok, isTrue, reason: o.leaks.join());
    expect(o.files.values.join().toLowerCase(), isNot(contains('zzfake')));
    expect(o.files['report.md'], contains('object keys replaced'));
  });

  test(
    'scanner flags email, phone, bearer and URL-with-query in any output',
    () {
      expect(
        findLeaks('{"a": "zzfake@example.com"}'),
        contains('email address'),
      );
      expect(
        findLeaks('call +20 100 123 4567 now'),
        contains('phone-like number'),
      );
      expect(findLeaks('{"a": "01001234567"}'), contains('phone-like number'));
      expect(findLeaks('Authorization: Bearer ZZFAKEabcdef12345'), isNotEmpty);
      expect(findLeaks('see https://x.example.net/a?b=1'), isNotEmpty);
      expect(findLeaks(r'{\"sessionid\":\"ZZFAKEq\"}'), isNotEmpty);
      expect(findLeaks('SessionID%3DZZFAKEq'), isNotEmpty);
      // not flagged: header NAME lists, placeholders, timestamps, short ints
      expect(
        findLeaks('{"h": ["cookie", "x-csrftoken", "authorization"]}'),
        isEmpty,
      );
      expect(
        findLeaks('{"csrftoken": "<v>", "sessionid": "<redacted>"}'),
        isEmpty,
      );
      expect(
        findLeaks(
          '{"taken_at": 1700000000, "device_timestamp": 1700000000000000}',
        ),
        isEmpty,
      );
    },
  );

  test('unknown base64 blobs: redacted or fail closed', () {
    final o = _out(File('$_fx/adv_base64.har').readAsStringSync());
    if (o != null) expect(o.toLowerCase(), isNot(contains('zzfake')));
  });

  test('large array (20k items) finishes in under 30 s and is clean', () {
    final big = {
      'reels_media': [
        for (var i = 0; i < 20000; i++)
          {
            'id': '${6000000000 + i}',
            'taken_at': 1700000000 + i,
            'media_type': 1,
            'caption': {'text': 'ZZFAKEcap$i'},
            'user': {
              'username': 'zzfakeu${i % 50}',
              'pk': '${7000000000 + i % 50}',
            },
            'image_versions2': {
              'candidates': [
                {
                  'url':
                      'https://scontent-fake5.cdninstagram.com/v/$i.jpg?oh=ZZFAKEOH$i&oe=ZZFAKEOE',
                },
              ],
            },
          },
      ],
    };
    final sw = Stopwatch()..start();
    final o = sanitizeHar(_har(big));
    sw.stop();
    expect(o.ok, isTrue, reason: '${o.leaks}');
    expect(sw.elapsed.inSeconds, lessThan(30));
    final text = o.files.values.join('\n').toLowerCase();
    expect(text, isNot(contains('zzfake')));
    expect(text, isNot(contains('6000000')));
  });

  // -------------------------------------------------------------------------
  // QA leak probes (QA-1..QA-6, all un-skipped). They assert the CORRECT
  // behaviour. They failed against the denylist sanitizer.
  // Contract for each: the fake value must not appear in the output (either
  // redacted, or the run fails closed = null).
  // -------------------------------------------------------------------------
  void noLeak(String name, Object? body, {String? url}) {
    test(name, () {
      final out = _out(_har(body, url: url ?? _u));
      if (out != null) {
        expect(out.toLowerCase(), isNot(contains('zzfake')));
      }
    });
  }

  group('QA leak probes (QA-1..QA-6)', () {
    noLeak('QA-1 sessionid%3D<value> in prose', {
      'a': 'redirect to login with sessionid%3D$_sid now',
    });
    noLeak('QA-1 sessionid%3d lowercase escape', {
      'a': 'x sessionid%3dZZFAKEenc1 y',
    });
    noLeak('QA-1 next= url with sessionid%3D', {
      'a': 'https://www.instagram.com/accounts/login/?next=/&sessionid%3DZZFAKEq1 z',
    });

    noLeak('QA-2 JSON text in a string (unescaped quotes)', {
      'a': '{"sessionid":"$_sid", "x": 1}',
    });
    noLeak('QA-2 JSON text inside string, doubly escaped', {
      'a': r'{\"sessionid\":\"' + _sid + r'\", \"x\": 1}',
    });
    noLeak('QA-2 short value', {
      'a': '{"sessionid":"ZZFAKEjis1", "x": 1}',
    });

    noLeak('QA-3 SessionID= uppercase', {
      'a': 'Cookie: SessionID=$_sid x',
    });

    for (final p in [
      '/api/v1/users/zzfakenm/usernameinfo/',
      '/api/v1/feed/user/zzfakenm/',
      '/api/v1/users/zzfakenm/info/',
      '/api/v1/friendships/show/zzfakenm/',
    ]) {
      test('QA-4 path $p', () {
        final out = _out(_har({'a': 1}, url: 'https://i.instagram.com$p'));
        if (out != null) expect(out, isNot(contains('zzfakenm')));
      });
    }

    noLeak('QA-5 business_email / phone / public_email', {
      'user': {
        'business_email': 'zzfake@example.com',
        'business_phone_number': '+20 ZZFAKE',
        'public_email': 'zzfake@example.com',
        'contact_phone_number': 'ZZFAKE',
        'business_address_json': '{"city_name":"ZZFAKE"}',
      },
    });
    noLeak('QA-5 biography_with_entities.raw_text', {
      'user': {
        'biography_with_entities': {'raw_text': 'ZZFAKE bio raw'},
      },
    });
    noLeak('QA-5 bio_links[].url on non-IG host path', {
      'user': {
        'bio_links': [
          {'url': 'https://linktr.ee/ZZFAKEme'},
        ],
      },
    });
    noLeak('QA-5 hashtag name / location name in story stickers', {
      'story_hashtags': [
        {
          'hashtag': {'name': 'ZZFAKEh'},
        },
      ],
      'story_locations': [
        {
          'location': {'name': 'ZZFAKE Cairo', 'short_name': 'ZZFAKEs'},
        },
      ],
    });
    noLeak('QA-5 sticker question text (poll/question)', {
      'story_polls': [
        {
          'poll_sticker': {'question': 'ZZFAKE question?'},
        },
      ],
    });

    noLeak('QA-6 X-CSRFToken key', {'X-CSRFToken': 'ZZFAKEcsrfK'});
    noLeak('QA-6 x-csrftoken key', {'x-csrftoken': 'ZZFAKEcsrfK'});
  });

  group('sanity: things that must keep working (regression guard)', () {
    for (final entry in {
      'sessionid key in body': {'sessionid': 'ZZFAKEv'},
      'sessionid= in prose': {'a': 'cookie sessionid=ZZFAKEv end'},
      'ds_user_id int key': {'ds_user_id': 5252525252},
      'Authorization key': {'Authorization': 'Bearer ZZFAKEb'},
      'csrf_token key': {'csrf_token': 'ZZFAKEc'},
      'nested JSON string, compact': {
        'a': jsonEncode({
          'b': jsonEncode({'sessionid': _sid}),
        }),
      },
    }.entries) {
      test(entry.key, () {
        final o = _out(_har(entry.value));
        if (o != null) {
          expect(o.toLowerCase(), isNot(contains('zzfake')));
          expect(o, isNot(contains('5252525252')));
        }
      });
    }
  });
}
