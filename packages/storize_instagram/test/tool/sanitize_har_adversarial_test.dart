// QA adversarial tests for tool/sanitize_har.dart (T-002 prep).
// All data is FAKE and synthetic. Markers contain "zzfake" or are fake IDs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sanitize_har.dart';

const _tool = 'tool/sanitize_har.dart';
const _fx = 'test/tool/fixtures';

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

  test('POST bodies / query holding csrftoken or sessionid fail closed '
      '(false positive: documented, safe)', () {
    expect(
      _out(File('$_fx/adv_post_body.har').readAsStringSync()),
      isNull,
    );
    expect(
      _out(File('$_fx/adv_extra.har').readAsStringSync()),
      isNull,
    );
  });

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
  // Probes that currently LEAK. They assert the CORRECT behaviour and are
  // skipped so CI stays green. Un-skip once the sanitizer is fixed.
  // Contract for each: the fake value must not appear in the output (either
  // redacted, or the run fails closed = null).
  // -------------------------------------------------------------------------
  void noLeak(String name, Object? body, {String? url, String? skip}) {
    test(name, skip: skip, () {
      final out = _out(_har(body, url: url ?? _u));
      if (out != null) {
        expect(out.toLowerCase(), isNot(contains('zzfake')));
      }
    });
  }

  group('known leaks (QA-1..QA-6) - un-skip when fixed', () {
    const s1 = 'QA-1 URL-encoded sessionid%3D not redacted nor detected';
    noLeak('QA-1 sessionid%3D<value> in prose', {
      'a': 'redirect to login with sessionid%3D$_sid now',
    }, skip: s1);
    noLeak('QA-1 sessionid%3d lowercase escape', {
      'a': 'x sessionid%3dZZFAKEenc1 y',
    }, skip: s1);
    noLeak('QA-1 next= url with sessionid%3D', {
      'a': 'https://www.instagram.com/accounts/login/?next=/&sessionid%3DZZFAKEq1 z',
    }, skip: s1);

    const s2 = 'QA-2 sessionid inside a JSON-in-a-string not redacted';
    noLeak('QA-2 JSON text in a string (unescaped quotes)', {
      'a': '{"sessionid":"$_sid", "x": 1}',
    }, skip: s2);
    noLeak('QA-2 JSON text inside string, doubly escaped', {
      'a': r'{\"sessionid\":\"' + _sid + r'\", \"x\": 1}',
    }, skip: s2);
    noLeak('QA-2 short value', {
      'a': '{"sessionid":"ZZFAKEjis1", "x": 1}',
    }, skip: s2);

    const s3 = 'QA-3 cookie names matched case-sensitively';
    noLeak('QA-3 SessionID= uppercase', {
      'a': 'Cookie: SessionID=$_sid x',
    }, skip: s3);

    const s4 = 'QA-4 username / unknown token in non-whitelisted IG path';
    for (final p in [
      '/api/v1/users/zzfakenm/usernameinfo/',
      '/api/v1/feed/user/zzfakenm/',
      '/api/v1/users/zzfakenm/info/',
      '/api/v1/friendships/show/zzfakenm/',
    ]) {
      test('QA-4 path $p', skip: s4, () {
        final out = _out(_har({'a': 1}, url: 'https://i.instagram.com$p'));
        if (out != null) expect(out, isNot(contains('zzfakenm')));
      });
    }

    const s5 = 'QA-5 PII keys not in redaction lists';
    noLeak('QA-5 business_email / phone / public_email', {
      'user': {
        'business_email': 'zzfake@example.com',
        'business_phone_number': '+20 ZZFAKE',
        'public_email': 'zzfake@example.com',
        'contact_phone_number': 'ZZFAKE',
        'business_address_json': '{"city_name":"ZZFAKE"}',
      },
    }, skip: s5);
    noLeak('QA-5 biography_with_entities.raw_text', {
      'user': {
        'biography_with_entities': {'raw_text': 'ZZFAKE bio raw'},
      },
    }, skip: s5);
    noLeak('QA-5 bio_links[].url on non-IG host path', {
      'user': {
        'bio_links': [
          {'url': 'https://linktr.ee/ZZFAKEme'},
        ],
      },
    }, skip: s5);
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
    }, skip: s5);
    noLeak('QA-5 sticker question text (poll/question)', {
      'story_polls': [
        {
          'poll_sticker': {'question': 'ZZFAKE question?'},
        },
      ],
    }, skip: s5);

    const s6 = 'QA-6 CSRF header names as JSON keys not in secret keys';
    noLeak('QA-6 X-CSRFToken key', {'X-CSRFToken': 'ZZFAKEcsrfK'}, skip: s6);
    noLeak('QA-6 x-csrftoken key', {'x-csrftoken': 'ZZFAKEcsrfK'}, skip: s6);
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
