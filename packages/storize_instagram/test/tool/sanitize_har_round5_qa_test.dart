// QA round 5 adversarial probes. All data is FAKE.
// ignore_for_file: lines_longer_than_80_chars
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
          'content': {
            'mimeType': 'application/json',
            'text': jsonEncode(body),
          },
        },
      },
    ],
  },
});

String? _out(Object? body, {String url = _u, Set<String> keep = const {}}) {
  final o = sanitizeHar(_har(body, url: url), keepKeys: keep);
  return o.ok ? o.files.values.join('\n') : null;
}

void noLeak(String name, Object? body, {String? skip, String? url}) {
  test(name, skip: skip, () {
    final out = _out(body, url: url ?? _u);
    if (out != null) expect(out.toLowerCase(), isNot(contains('zzfake')));
  });
}

Future<({int code, String out, String err})> _cli(List<String> args) async {
  final o = StringBuffer();
  final e = StringBuffer();
  final code = await run(args, out: o, err: e);
  return (code: code, out: '$o', err: '$e');
}

void main() {
  group('1 strict key rule', () {
    noLeak('snake sibling next to allowlisted', {
      'pk': '1',
      'zzfake_nour': {'a': 1},
    });
    noLeak('mixed value types, most keys allowlisted, one username', {
      'pk': '1',
      'id': '1',
      'username': 'x',
      'is_private': false,
      'zzfake_nour': 3,
    });
    noLeak('exactly 2 keys, all objects', {
      'zzfake_a': {'x': 1},
      'zzfake_b': {'x': 1},
    });
    noLeak('exactly 2 keys, one allowlisted one username, same scalar', {
      'count': 1,
      'zzfake_a': 2,
    });
    noLeak('exactly half allowlisted (2 of 4), same scalar', {
      'count': 1,
      'url': 2,
      'zzfake_a': 3,
      'zzfake_b': 4,
    });
    noLeak('half allowlisted objects', {
      'user': {'a': 1},
      'owner': {'a': 1},
      'zzfake_a': {'a': 1},
      'zzfake_b': {'a': 1},
    });
    noLeak('viewers with count (round-4 repro)', {
      'viewers': {
        'count': 2,
        'zzfake_three': {'seen': true},
      },
    });
    noLeak('user named like a key, in a 3 username map', {
      'seen_by': {
        'user': {'a': 1},
        'zzfake_two': {'a': 1},
        'zzfake_three': {'a': 1},
      },
    });
    test('RESIDUAL: usernames equal to allowlisted words survive in a non-dynamic map', () {
      // Two accounts named `user` and `owner`: 2 of 2 keys allowlisted, so the
      // map is not dynamic and both names are kept. Only the allowlisted
      // word itself can leak, never an arbitrary username.
      final out = _out({
        'seen_by': {
          'user': {'a': 1},
          'owner': {'a': 1},
        },
      })!;
      expect(out, contains('"user"'));
    });
    test('1-key map keyed by an allowlisted-word username is kept (indistinguishable from schema)', () {
      expect(
        _out({
          'seen_by': {
            'text': {'a': 1},
          },
        }),
        contains('"text"'),
      );
    });
    noLeak('username as key inside a list element', {
      'items': [
        {'zzfake_a': 1},
        {'zzfake_b': 'x'},
      ],
    });
    noLeak('username keys with ID values inside nested replaced key', {
      'zzfake_a': {
        'zzfake_b': ['1234567890', 1234567890],
      },
    });
    noLeak('case variants of allowlisted keys', {
      'Username': 'x',
      'PK': '1',
      'zzfake': 1,
      'User': <String, Object?>{},
    });
    noLeak('key equal to key_N placeholder and username', {
      'key_1': 'a',
      'zzfake': 'b',
      'key_2': 'c',
    });
    test('key_N is consistent and report never shows the original key', () {
      final o = sanitizeHar(
        _har({
          'a1': {'zzfake_n': 1},
          'a2': {'zzfake_n': 2},
        }),
      );
      final r = o.files['report.md']!;
      expect(r.toLowerCase(), isNot(contains('zzfake')));
      expect(r, contains('Replaced object keys'));
    });
    test(
      'all-bool object with a minority of allowlisted keys loses them (usefulness, low)',
      () {
        final out = _out({
          'x': {
            'is_private': false,
            'is_verified': false,
            'is_new_to_instagram': false,
            'is_embeds_disabled': false,
            'is_joined_recently': false,
          },
        })!;
        expect(out, contains('"is_private"'));
      },
      skip: 'QA-24 (accepted usefulness trade-off, Lead decision round 6; use --keep-key / keep_keys.txt to rescue schema keys): dynamic-map rule also replaces schema keys in all-bool/all-string objects with a majority of unknown keys',
    );
  });

  group('2 request host', () {
    test(
      'username subdomain of instagram.com is copied verbatim (QA-25)',
      () {
        final out = _out({
          'status': 'ok',
        }, url: 'https://zzfakenour.instagram.com/api/v1/x/');
        expect(out, isNotNull);
        expect(out!.toLowerCase(), isNot(contains('zzfake')));
      },
    );
    test('userinfo and port are not copied', () {
      final out = _out({
        'status': 'ok',
      }, url: 'https://zzfake:pw@www.instagram.com:8443/api/v1/x/')!;
      expect(out.toLowerCase(), isNot(contains('zzfake')));
    });
    test('non-instagram hosts are dropped entirely', () {
      final o = sanitizeHar(
        _har({'status': 'ok'}, url: 'https://zzfake.example.com/api/'),
      );
      expect(o.files.values.join().toLowerCase(), isNot(contains('zzfake')));
    });
  });

  group('3 keep-key opt-in', () {
    late Directory d;
    late File har;
    setUp(() {
      d = Directory.systemTemp.createTempSync('qa5');
      har = File('${d.path}/in.har')
        ..writeAsStringSync(
          _har({
            'pk': '1',
            'zzfake_nour': {'a': 1},
          }),
        );
    });
    tearDown(() => d.deleteSync(recursive: true));

    for (final bad in [
      'sessionid=abcdef123456',
      'zzfake nour',
      'zzfake@example.com',
      'a.b',
      '9starts_digit',
      'https://x.example/zzfake',
      'x' * 61,
      'A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6',
      'deadbeefdeadbeefdeadbeefdeadbeef',
    ]) {
      test(
        'invalid --keep-key is rejected and never echoed: ${bad.length > 20 ? bad.substring(0, 6) : bad}',
        () async {
          final r = await _cli(['--keep-key', bad, har.path, '${d.path}/o']);
          expect(r.code, 2);
          expect(Directory('${d.path}/o').existsSync(), isFalse);
          expect(r.err + r.out, isNot(contains(bad)));
        },
      );
    }
    test(
      'invalid line in --keep-keys file is rejected and never echoed',
      () async {
        final f = File('${d.path}/k.txt')
          ..writeAsStringSync('# c\nok_name\nsessionid=zzfake1\n');
        final r = await _cli(['--keep-keys', f.path, har.path, '${d.path}/o']);
        expect(r.code, 2);
        expect(r.err + r.out, isNot(contains('zzfake')));
        expect(r.err, contains('line 3'));
      },
    );
    test('username-shaped opt-in is accepted by design (user responsibility): kept only if exact', () async {
      final r = await _cli([
        '--keep-key',
        'zzfake_nour',
        har.path,
        '${d.path}/o',
      ]);
      expect(r.code, 0);
      final body = File('${d.path}/o/bodies/001_friendships.json')
          .readAsStringSync();
      expect(body, contains('zzfake_nour'));
      expect(r.out + r.err, isNot(contains('zzfake')));
      // The opted-in name also appears in report.md paths (same as the body).
      expect(
        File('${d.path}/o/report.md').readAsStringSync(),
        contains('zzfake_nour'),
      );
    });
    test('opt-in of a secret key name stays redacted', () {
      final out = _out(
        {'sessionid': 'zzfakesecret', 'pk': '1'},
        keep: {'sessionid'},
      )!;
      expect(out, isNot(contains('zzfakesecret')));
    });
    test('opt-in of fbsr_ and key_N names is ignored', () {
      final out = _out(
        {'fbsr_123': 'zzfake', 'key_1': 'zzfake2', 'pk': '1'},
        keep: {'fbsr_123', 'key_1'},
      )!;
      expect(out.toLowerCase(), isNot(contains('zzfake')));
      expect(out, isNot(contains('fbsr_123')));
    });
    test('opt-in does not widen value rules', () {
      final out = _out(
        {'zzfake_field': 'zzfake_value'},
        keep: {'zzfake_field'},
      )!;
      expect(out, isNot(contains('zzfake_value')));
    });
    test('shipped keep_keys.txt holds only the reviewed schema names', () {
      // T-002 (2026-11-20): each name was checked against the real capture.
      // Adding a name needs a review: extend this list in the same PR.
      const reviewed = {
        'xdt_api__v1__feed__reels_media',
        'xdt_api__v1__feed__user_timeline_graphql_connection',
        'xdt_viewer',
        'carousel_media_count',
        'timeline_pinned_user_ids',
        'coauthor_producers',
        'media_count',
      };
      final lines = File('tool/keep_keys.txt')
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toSet();
      expect(lines, reviewed);
    });
  });

  group('4 usefulness: failure map values', () {
    for (final v in [
      'login_required',
      'checkpoint_required',
      'feedback_required',
      'challenge_required',
      'consent_required',
      'rate_limited',
    ]) {
      test('message $v survives', () {
        expect(_out({'message': v, 'status': 'fail'}), contains(v));
        expect(_out({'error_type': v}), contains(v));
      });
    }
    test(
      'status ok/fail survive; require_login and spam keep their booleans',
      () {
        final out = _out({
          'status': 'fail',
          'require_login': true,
          'spam': true,
        })!;
        expect(out, contains('"fail"'));
        expect(out, contains('"require_login": true'));
      },
    );
    for (final v in [
      'user_has_logged_out',
      'Not authorized to view user',
      'sentry_block',
      'rate_limit_error',
      'unauthorized',
      'Invalid parameters',
    ]) {
      test('real-world message "$v" survives (QA-26, low)', () {
        expect(_out({'message': v, 'status': 'fail'}), contains(v));
      });
    }
    test('values with a username in message stay replaced', () {
      final out = _out({'message': 'zzfake_nour is private'})!;
      expect(out.toLowerCase(), isNot(contains('zzfake')));
    });
  });

  group('5 fail closed', () {
    test('token in an instagram host label is replaced (QA-25)', () {
      final o = sanitizeHar(
        _har(
          {'status': 'ok'},
          url: 'https://a1b2c3d4e5f60718293a4b5c6d7e8f90.instagram.com/api/v1/x/',
        ),
      );
      expect(o.ok, isTrue);
      expect(o.files.values.join(), isNot(contains('a1b2c3d4')));
      expect(o.files.values.join(), contains('<label>.instagram.com'));
    });
  });
}
