// QA round 4: default-deny object keys (QA-10), doc_id/query_hash shape
// (QA-11), enum-like values (QA-12), summary.json names and User-Agent
// (QA-13), key_N consistency, and survival of the TECH_SPEC 4.1 fields.
// All data is FAKE.
// Tests walk decoded JSON; dynamic access keeps the assertions readable.
// ignore_for_file: avoid_dynamic_calls, strict_raw_type, cast_nullable_to_non_nullable, lines_longer_than_80_chars, avoid_redundant_argument_values
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sanitize_har.dart';

const _u = 'https://www.instagram.com/api/v1/friendships/show_many/';
const _g = 'https://www.instagram.com/graphql/query/';

Map<String, Object?> _entry(
  Object? body, {
  String url = _u,
  List<Map<String, String>> headers = const [],
}) => {
  'request': {'method': 'GET', 'url': url, 'headers': headers},
  'response': {
    'status': 200,
    'content': {'mimeType': 'application/json', 'text': jsonEncode(body)},
  },
};

String _har(List<Map<String, Object?>> entries) => jsonEncode({
  'log': {'entries': entries},
});

SanitizeOutcome _run(
  Object? body, {
  String url = _u,
  List<Map<String, String>> headers = const [],
}) => sanitizeHar(_har([_entry(body, url: url, headers: headers)]));

/// Strict: must NOT fail closed, and nothing "zzfake" may survive.
String _clean(
  Object? body, {
  String url = _u,
  List<Map<String, String>> headers = const [],
}) {
  final o = _run(body, url: url, headers: headers);
  expect(o.ok, isTrue, reason: 'fail-closed is not an acceptable fix here');
  final all = o.files.values.join('\n');
  expect(all.toLowerCase(), isNot(contains('zzfake')));
  return all;
}

Map<String, dynamic> _body(SanitizeOutcome o, [int i = 0]) {
  final f = o.files.entries.where((e) => e.key.startsWith('bodies/')).toList();
  return jsonDecode(f[i].value) as Map<String, dynamic>;
}

Map<String, dynamic> _summary(SanitizeOutcome o) =>
    jsonDecode(o.files['summary.json']!) as Map<String, dynamic>;

void main() {
  group('QA-10 object keys are default-deny (strict)', () {
    test('repro: users keyed by username', () {
      final o = _run({
        'users': {
          'zzfake_nour.k': {'pk': '1234567890'},
        },
      });
      expect(o.ok, isTrue);
      final j = _body(o);
      expect(j['users'], isA<Map>());
      expect((j['users'] as Map).keys.single, startsWith('key_'));
      expect(o.files.values.join().toLowerCase(), isNot(contains('zzfake')));
      // The structure below the username is untouched.
      expect(((j['users'] as Map).values.single as Map).keys, ['pk']);
    });

    test('safe-word usernames in dynamic maps are replaced too', () {
      // Passes the safe-word shape, but the parent is a map of ids.
      for (final parent in ['users', 'friendship_statuses', 'reels']) {
        final out = _clean({
          parent: {
            'zzfakenour': {'pk': '1234567890'},
            'zzfake_two': {'pk': '1234567891'},
          },
        });
        expect(out, contains('key_1'));
        expect(out, contains('key_2'));
      }
    });

    test('lists under a dynamic-map parent are not treated as dynamic', () {
      final j = _body(
        _run({
          'users': [
            {'pk': '1234567890', 'username': 'zzfakeuser'},
          ],
        }),
      );
      expect(((j['users'] as List).single as Map).keys, ['pk', 'username']);
    });

    test('unknown safe-word keys are replaced even next to known keys', () {
      final j = _body(
        _run({
          'pk': '1234567890',
          'brand_new_field': 1,
          'zzfake_nour': 2,
        }),
      );
      expect(j.keys.toSet(), hasLength(3));
      expect(j.containsKey('pk'), isTrue);
      expect(j.keys.where((k) => k.startsWith('key_')), hasLength(2));
    });

    test('unknown keys with only unknown siblings are replaced', () {
      final j = _body(
        _run({
          'zzfakeinner': {'zzfakeinner2': 1},
        }),
      );
      expect(j.keys.single, startsWith('key_'));
      expect((j.values.single as Map).keys.single, startsWith('key_'));
    });

    test('uppercase, spaced, unicode, email, phone, URL keys are replaced', () {
      _clean({
        'pk': '1234567890',
        'ZZFAKE_Nour': 1,
        'Zzfake Real Name': 2,
        'zzfake_用户': 3,
        'zzfake@example.com': 4,
        '+201000000000': 5,
        'https://linktr.ee/zzfake': 6,
        '//zzfake.carrd.co/x': 7,
        'zzfake.user': 8,
      });
    });

    test('a real key named like a placeholder cannot collide', () {
      final j = _body(_run({'pk': '1234567890', 'key_1': 1, 'zzfake_x.y': 2}));
      expect(j.keys.toSet(), hasLength(3));
    });

    test('same original key maps to the same key_N across the whole HAR', () {
      final o = sanitizeHar(
        _har([
          _entry({
            'users': {
              'zzfake_a': {'pk': '1234567890'},
              'zzfake_b': {'pk': '1234567891'},
            },
          }),
          _entry({
            'friendship_statuses': {
              'zzfake_b': {'following': true},
              'zzfake_a': {'following': false},
            },
          }),
        ]),
      );
      expect(o.ok, isTrue);
      final first = (_body(o, 0)['users'] as Map).keys.toList();
      final second = (_body(o, 1)['friendship_statuses'] as Map).keys.toList();
      expect(first, ['key_1', 'key_2']);
      expect(second, ['key_2', 'key_1']);
      final unrelated = _run({
        'users': {'zzfake_c': 1},
      });
      expect(
        (_body(unrelated)['users'] as Map).keys.single,
        'key_1',
        reason: 'numbering is per HAR, not global',
      );
    });

    test('the report says how many keys were replaced', () {
      final o = sanitizeHar(
        _har([
          _entry({
            'users': {
              'zzfake_a': {'pk': '1234567890'},
              'zzfake_b': {'pk': '1234567891'},
            },
          }),
          _entry({
            'users': {
              'zzfake_a': {'pk': '1234567890'},
            },
          }),
        ]),
      );
      expect(
        o.files['report.md'],
        contains('object keys replaced with key_N: 3 (2 distinct)'),
      );
    });

    test('numeric id keys still map to user_N / media_N', () {
      final out = _clean({
        'friendship_statuses': {
          '1234567890': {'following': true},
        },
      });
      expect(out, matches(RegExp('(user|media)_1')));
    });

    test('opt-in keys (keepKeys) are kept, exact and case-sensitive', () {
      final o = sanitizeHar(
        _har([
          _entry({
            'pk': '1234567890',
            'xdt_api__v1__feed__user_timeline_graphql_connection': 1,
            'profilePicUrl': 2,
            'ProfilePicUrl': 3,
            'zzfake_nour': 4,
          }),
        ]),
        keepKeys: {
          'xdt_api__v1__feed__user_timeline_graphql_connection',
          'profilePicUrl',
        },
      );
      expect(o.ok, isTrue);
      final j = _body(o);
      expect(
        j.containsKey('xdt_api__v1__feed__user_timeline_graphql_connection'),
        isTrue,
      );
      expect(j.containsKey('profilePicUrl'), isTrue);
      expect(j.containsKey('ProfilePicUrl'), isFalse);
      expect(o.files.values.join().toLowerCase(), isNot(contains('zzfake')));
      expect(o.files['report.md'], contains('keep-list entries used: 2 of 2'));
    });

    test('xdt_ / xig_ names are not kept without an opt-in (QA-16)', () {
      final j = _body(
        _run({
          'data': {'xdt_zzfake_user': 1},
        }),
      );
      expect((j['data'] as Map).keys.single, startsWith('key_'));
    });
  });

  group('dynamic maps (QA-14, QA-15)', () {
    test('unknown map with a user literally named like a field', () {
      final out = _clean({
        'seen_by': {
          'user': {'a': 1},
          'zzfake_two': {'a': 1},
        },
      });
      expect(out, isNot(contains('"user": {\n      "a"')));
    });

    test('allowlisted-looking keys inside a dynamic map are replaced', () {
      final j = _body(
        _run({
          'seen_by': {
            'user': {'a': 1},
            'zzfake_three': {'a': 1},
            'zzfake_two': {'a': 1},
          },
        }),
      );
      final inner = j.values.single as Map;
      expect(inner.keys.every((k) => '$k'.startsWith('key_')), isTrue);
    });

    test('viewers map with a count sibling stays clean', () {
      _clean({
        'viewers': {
          'count': 2,
          'zzfake_nour': {'seen': true},
          'zzfake_two': {'seen': true},
        },
      });
    });

    test('scalar maps of one type are dynamic', () {
      final j = _body(
        _run({
          'tagged': {'id': true, 'zzfake_a': false, 'zzfake_b': true},
        }),
      );
      expect(
        (j['key_1'] as Map).keys.every((k) => '$k'.startsWith('key_')),
        isTrue,
      );
    });

    test('schema objects are not misclassified', () {
      final j = _body(
        _run({
          'user': {'pk': '1234567890', 'username': 'x', 'is_private': false},
          'dimensions': {'width': 1, 'height': 2},
          'friendship_status': {'following': true, 'followed_by': false},
        }),
      );
      expect((j['user'] as Map).keys, ['pk', 'username', 'is_private']);
      expect((j['dimensions'] as Map).keys, ['width', 'height']);
      expect((j['friendship_status'] as Map).keys, [
        'following',
        'followed_by',
      ]);
    });

    test('keep-list entries count as allowlisted for detection', () {
      final o = sanitizeHar(
        _har([
          _entry({
            'widget': {'alpha_field': 1, 'beta_field': 2},
          }),
        ]),
        keepKeys: {'alpha_field', 'beta_field', 'widget'},
      );
      expect((_body(o)['widget'] as Map).keys, ['alpha_field', 'beta_field']);
    });
  });

  group('report lists replaced keys by placeholder only', () {
    test('placeholder, count, path; no original key', () {
      final o = sanitizeHar(
        _har([
          _entry({
            'seen_by': {
              'zzfake_a': {'pk': '1234567890'},
              'zzfake_b': {'pk': '1234567891'},
            },
          }),
          _entry({
            'seen_by': {
              'zzfake_a': {'pk': '1234567890'},
              'zzfake_c': {'pk': '1234567892'},
            },
          }),
        ]),
      );
      final r = o.files['report.md']!;
      expect(r.toLowerCase(), isNot(contains('zzfake')));
      expect(r, contains('## Replaced object keys'));
      expect(r, contains('| key_2 | 2 | yes |'));
      expect(r, contains(r'`$.key_1.key_2` x2'));
      expect(r, contains('yes'));
      expect(r, contains('keep_keys.txt'));
    });
  });

  group('QA-11 doc_id and query_hash shape', () {
    Map<String, dynamic> query(String qs) {
      final o = _run({'a': 1}, url: '$_g?$qs');
      expect(o.ok, isTrue, reason: '${o.leaks}');
      return (_summary(o)['requests'] as List).single['query']
          as Map<String, dynamic>;
    }

    test('valid digits / hex are kept', () {
      final q = query(
        'doc_id=1234567890123&query_hash=0123456789abcdef0123456789abcdef',
      );
      expect(q['doc_id'], '1234567890123');
      expect(q['query_hash'], '0123456789abcdef0123456789abcdef');
    });

    test('words, short digits, mixed case, long values become <v>', () {
      for (final bad in [
        'zzfakeuser',
        '12345',
        '123456789012345678901',
        'ZZFAKEabcdef0123',
      ]) {
        expect(query('doc_id=$bad')['doc_id'], '<v>', reason: bad);
      }
      for (final bad in [
        'zzfake2',
        '0123456789abcde',
        '0123456789ABCDEF0123',
        'g123456789abcdef',
        'a' * 65,
      ]) {
        expect(query('query_hash=$bad')['query_hash'], '<v>', reason: bad);
      }
    });

    test('POST body doc_id obeys the same shape', () {
      Object? post(String docId) => {
        'request': {
          'method': 'POST',
          'url': _g,
          'headers': <Object?>[],
          'postData': {
            'mimeType': 'application/x-www-form-urlencoded',
            'text': 'doc_id=$docId&variables=%7B%7D',
          },
        },
        'response': {
          'status': 200,
          'content': {'mimeType': 'application/json', 'text': '{"a":1}'},
        },
      };
      final ok = sanitizeHar(
        _har([post('1234567890123')! as Map<String, Object?>]),
      );
      final bad = sanitizeHar(
        _har([post('zzfakeuser')! as Map<String, Object?>]),
      );
      expect(
        (_summary(ok)['requests'] as List).single['postData']['docId'],
        '1234567890123',
      );
      expect(
        (_summary(bad)['requests'] as List).single['postData'].containsKey(
          'docId',
        ),
        isFalse,
      );
      expect(bad.files.values.join().toLowerCase(), isNot(contains('zzfake')));
    });
  });

  group('QA-12 enum-like values', () {
    Map<String, dynamic> enums(Map<String, Object?> m) {
      final o = _run({'pk': '1234567890', ...m});
      expect(o.ok, isTrue, reason: '${o.leaks}');
      expect(o.files.values.join().toLowerCase(), isNot(contains('zzfake')));
      return _body(o);
    }

    test('known values pass, including GraphQL typenames', () {
      final j = enums({
        'status': 'ok',
        'product_type': 'clips',
        'type': 'GraphImage',
        '__typename': 'XDTGraphImage',
        'audience': 'besties',
      });
      expect(j['status'], 'ok');
      expect(j['product_type'], 'clips');
      expect(j['type'], 'GraphImage');
      expect(j['__typename'], 'XDTGraphImage');
      expect(j['audience'], 'besties');
    });

    test('anything else becomes a placeholder', () {
      final j = enums({
        'status': 'zzfake user said hi',
        'product_type': 'zzfake@x.com',
        'type': 'zzfake-user',
        '__typename': '9zzfake',
        'audience': 'a' * 33,
        'media_type': 'zzfake.name',
      });
      for (final k in [
        'status',
        'product_type',
        'type',
        '__typename',
        'audience',
        'media_type',
      ]) {
        expect('${j[k]}', startsWith('<'), reason: k);
      }
    });
  });

  group('QA-13 summary.json names and User-Agent', () {
    test('coarse User-Agent keeps family, major version and OS only', () {
      expect(
        coarseUserAgent(
          'Mozilla/5.0 (Linux; Android 14; ZZFAKE-Model Build/ZZFAKE123; wv) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
          'Chrome/131.0.6778.39 Mobile Safari/537.36',
        ),
        'Chrome/131 (Android, WebView)',
      );
      expect(
        coarseUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.1.2',
        ),
        'Edge/130 (Windows)',
      );
      expect(
        coarseUserAgent(
          'Instagram 300.1.0.2.99 Android (33/13; 420dpi; ZZFAKE; zzfakedev)',
        ),
        'Instagram/300 (Android)',
      );
      expect(coarseUserAgent('zzfake custom agent'), '<ua>');
    });

    test('summary has no device model or build id', () {
      final o = _run(
        {'a': 1},
        headers: [
          {
            'name': 'User-Agent',
            'value':
                'Mozilla/5.0 (Linux; Android 14; ZZFAKE-Model Build/ZZFAKE1) '
                'AppleWebKit/537.36 Chrome/131.0.6778.39 Mobile Safari/537.36',
          },
          {'name': 'x-ig-app-id', 'value': '936619743392459'},
          {'name': 'X-ZZFake-User-9', 'value': 'v'},
          {'name': 'x-zzfake_user.name', 'value': 'v'},
          {'name': 'accept', 'value': '*/*'},
        ],
      );
      expect(o.ok, isTrue, reason: '${o.leaks}');
      final r = (_summary(o)['requests'] as List).single;
      expect(r['requestHeaders']['user-agent'], 'Chrome/131 (Android)');
      expect(r['requestHeaders']['x-ig-app-id'], '936619743392459');
      expect(r['requestHeaderNames'], contains('x-ig-app-id'));
      expect(r['requestHeaderNames'], contains('<hdr>'));
      expect(
        (r['requestHeaderNames'] as List).where((n) => '$n'.contains('zz')),
        isEmpty,
        reason: 'digits, dots and underscores in header names are not kept',
      );
      final all = o.files['summary.json']!.toLowerCase();
      expect(all, isNot(contains('zzfake-model')));
      expect(all, isNot(contains('build/')));
      expect(all, isNot(contains('6778')));
    });

    test('non-numeric x-ig-app-id value is not kept', () {
      final o = _run(
        {'a': 1},
        headers: [
          {'name': 'x-ig-app-id', 'value': 'zzfakeuser'},
        ],
      );
      final r = (_summary(o)['requests'] as List).single;
      expect(r['requestHeaders']['x-ig-app-id'], '<v>');
    });

    test('query names: known or short lower-case pattern, else <name>', () {
      final o = _run(
        {'a': 1},
        url:
            '$_u?username=x&reel_ids=1&ZZFake_User=1&zzfake.user=1'
            '&zzfake_user_9=1&aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=1'
            '&__a=1',
      );
      expect(o.ok, isTrue, reason: '${o.leaks}');
      final q = (_summary(o)['requests'] as List).single['query'] as Map;
      expect(q.keys, containsAll(['username', 'reel_ids', '__a', '<name>']));
      expect(
        q.keys.where((k) => '$k'.toLowerCase().contains('zzfake')),
        isEmpty,
        reason: 'names with uppercase, dots, digits must not survive',
      );
    });
  });

  group('TECH_SPEC 4.1 fields survive default-deny on synthetic.har', () {
    late SanitizeOutcome o;
    late Map<String, String> bodyByCandidate;

    setUpAll(() {
      o = sanitizeHar(File('test/fixtures/synthetic.har').readAsStringSync());
      expect(o.ok, isTrue, reason: '${o.leaks}');
      bodyByCandidate = {
        for (final r in _summary(o)['requests'] as List)
          if (r['candidate'] != null && r['bodyFile'] != null)
            r['candidate'] as String: o.files[r['bodyFile'] as String]!,
      };
    });

    Object? at(String cand, String path) {
      Object? cur = jsonDecode(bodyByCandidate[cand]!);
      for (final seg in path.split('.')) {
        if (seg.endsWith('[]')) {
          cur = (cur as Map)[seg.substring(0, seg.length - 2)];
          cur = (cur as List).first;
        } else if (seg == '*') {
          cur = (cur as Map).values.first;
        } else {
          expect(cur, isA<Map>(), reason: '$cand $path at $seg');
          expect((cur as Map).containsKey(seg), isTrue, reason: '$cand $path');
          cur = cur[seg];
        }
      }
      return cur;
    }

    test('all of IG-1, IG-2, IG-4, IG-5 are present', () {
      expect(bodyByCandidate.keys, containsAll(['IG-1', 'IG-2', 'IG-4']));
      expect(bodyByCandidate.keys.any((k) => k == 'IG-5'), isTrue);
    });

    test('IG-1 user fields', () {
      for (final f in [
        'id',
        'username',
        'full_name',
        'is_private',
        'profile_pic_url',
      ]) {
        at('IG-1', 'data.user.$f');
      }
      at('IG-1', 'data.user.edge_owner_to_timeline_media.edges[].node.id');
      at(
        'IG-1',
        'data.user.edge_owner_to_timeline_media.edges[].node.taken_at_timestamp',
      );
    });

    test('IG-2 story item fields', () {
      for (final f in [
        'pk',
        'taken_at',
        'expiring_at',
        'media_type',
        'product_type',
        'image_versions2',
        'video_versions',
        'video_duration',
        'has_audio',
      ]) {
        at('IG-2', 'reels.*.items[].$f');
      }
      at('IG-2', 'reels.*.items[].image_versions2.candidates[].url');
      at('IG-2', 'reels.*.items[].image_versions2.candidates[].width');
      at('IG-2', 'reels.*.items[].video_versions[].height');
      at('IG-2', 'reels.*.user.pk');
    });

    test('IG-4 current_user fields', () {
      at('IG-4', 'user.pk');
      at('IG-4', 'user.username');
    });

    test('IG-5 post fields', () {
      for (final f in [
        'pk',
        'code',
        'taken_at',
        'media_type',
        'product_type',
        'carousel_media',
        'caption',
        'image_versions2',
      ]) {
        final raw = bodyByCandidate['IG-5']!;
        expect(raw, contains('"$f"'), reason: f);
      }
      at('IG-5', 'items[].caption.text');
    });

    test('IDs stay linked: story pk user_N equals user.pk', () {
      final reels =
          (jsonDecode(bodyByCandidate['IG-2']!) as Map)['reels'] as Map;
      final id = reels.keys.first;
      expect((reels[id] as Map)['user']['pk'], id);
    });
  });

  group('round 5: known values, strict names, ints, CLI', () {
    test('QA-20: failure-map values survive, anything else does not', () {
      final j = _body(
        _run({
          'message': 'login_required',
          'status': 'fail',
          'error_type': 'checkpoint_required',
          'require_login': true,
        }),
      );
      expect(j['message'], 'login_required');
      expect(j['error_type'], 'checkpoint_required');
      expect(j['status'], 'fail');
      for (final v in [
        'feedback_required',
        'challenge_required',
        'consent_required',
        'rate_limited',
        'Please wait a few minutes before you try again.',
      ]) {
        expect(_body(_run({'message': v, 'status': 'fail'}))['message'], v);
      }
      final bad = _body(
        _run({
          'message': 'zzfake_nour is blocked',
          'error_type': 'zzfake_nour',
          'status': 'fail',
        }),
      );
      expect('${bad['message']}', startsWith('<str:'));
      expect('${bad['error_type']}', startsWith('<str:'));
    });

    test('QA-17: identifier-shaped but unknown enum values are replaced', () {
      final out = _clean({
        'pk': '1',
        'type': 'zzfake_nour',
        'status': 'zzfake_nour',
        'audience': 'zzfake',
        'product_type': 'zzfake_x',
        'media_type': 'zzfake',
        'reel_type': 'zzfake',
      });
      expect(out, contains('<str:'));
    });

    test('QA-18: 10 to 20 digit ints under non-id keys are mapped', () {
      final o = _run({
        'mentioned': 1234567890,
        'pk': '1',
        'big': 12345678901234,
      });
      final out = o.files.values.join();
      expect(out, isNot(contains('1234567890')));
      expect(out, isNot(contains('12345678901234')));
      // Timestamps stay.
      final t = _body(_run({'taken_at': 1700000000}));
      expect(t['taken_at'], 1700000000);
    });

    test('QA-19: header and query names need a known-list match', () {
      final o = _run(
        {'a': 1},
        url: '$_u?zzfake_nour=1&zzfake&username=x',
        headers: [
          {'name': 'zzfake-nour', 'value': 'x'},
          {'name': 'accept', 'value': '*/*'},
        ],
      );
      expect(o.ok, isTrue);
      expect(o.files['summary.json']!.toLowerCase(), isNot(contains('zzfake')));
      final r = (_summary(o)['requests'] as List).single;
      expect(r['requestHeaderNames'], ['<hdr>', 'accept']);
      expect((r['query'] as Map).keys, containsAll(['username', '<name>']));
    });

    test('QA-22: accept/content-type values must be known MIME types', () {
      final o = _run(
        {'a': 1},
        headers: [
          {'name': 'accept', 'value': 'zzfake'},
          {'name': 'content-type', 'value': 'zzfake'},
        ],
      );
      expect(o.files['summary.json']!.toLowerCase(), isNot(contains('zzfake')));
      final ok = _run(
        {'a': 1},
        headers: [
          {'name': 'accept', 'value': 'application/json, text/plain, */*'},
          {
            'name': 'content-type',
            'value': 'application/x-www-form-urlencoded; charset=UTF-8',
          },
        ],
      );
      final h = (_summary(ok)['requests'] as List).single['requestHeaders'];
      expect(h['accept'], 'application/json, text/plain, */*');
      expect(h['content-type'], contains('charset=UTF-8'));
    });

    test('QA-23: method and response mimeType must be known', () {
      final har = jsonEncode({
        'log': {
          'entries': [
            {
              'request': {
                'method': 'zzfake',
                'url': _u,
                'headers': <Object?>[],
              },
              'response': {
                'status': 200,
                'content': {
                  'mimeType': 'application/zzfake_nour',
                  'text': '{}',
                },
              },
            },
          ],
        },
      });
      final o = sanitizeHar(har);
      expect(o.files.values.join().toLowerCase(), isNot(contains('zzfake')));
    });

    group('CLI keep options', () {
      late Directory tmp;
      late String input;
      setUp(() {
        tmp = Directory.systemTemp.createTempSync('har_keep_');
        input = '${tmp.path}/in.har';
        File(input).writeAsStringSync(
          _har([
            _entry({'pk': '1234567890', 'brand_new_field': 1, 'zzfake_x': 2}),
          ]),
        );
      });
      tearDown(() => tmp.deleteSync(recursive: true));

      Future<(int, String, String)> cli(
        List<String> extra, {
        String? def,
      }) async {
        final out = StringBuffer();
        final err = StringBuffer();
        final code = await run(
          [input, '${tmp.path}/out', ...extra],
          out: out,
          err: err,
          defaultKeepKeysPath: def,
        );
        return (code, out.toString(), err.toString());
      }

      String body() {
        final d = Directory('${tmp.path}/out/bodies').listSync().single;
        return File(d.path).readAsStringSync();
      }

      test('without options every unknown key is replaced', () async {
        final (code, _, _) = await cli([]);
        expect(code, 0);
        expect(body(), isNot(contains('brand_new_field')));
        expect(body(), isNot(contains('zzfake')));
      });

      test('--keep-key (repeatable) and --keep-keys file', () async {
        File('${tmp.path}/k.txt').writeAsStringSync(
          '# comment\n\n  brand_new_field  \n',
        );
        final (code, _, _) = await cli([
          '--keep-key',
          'unused_name',
          '--keep-keys',
          '${tmp.path}/k.txt',
        ]);
        expect(code, 0);
        expect(body(), contains('brand_new_field'));
        expect(body(), isNot(contains('zzfake')));
      });

      test('default keep_keys.txt is read when given', () async {
        File('${tmp.path}/keep_keys.txt')
            .writeAsStringSync('brand_new_field\n');
        final (code, _, _) = await cli([], def: '${tmp.path}/keep_keys.txt');
        expect(code, 0);
        expect(body(), contains('brand_new_field'));
      });

      test('invalid keep keys exit 2 without echoing the value', () async {
        for (final bad in ['zzfake@x.com', 'a b', 'https://zzfake.com', '']) {
          final (code, _, err) = await cli(['--keep-key', bad]);
          if (bad.isEmpty) {
            expect(code, 0);
            continue;
          }
          expect(code, 2, reason: bad);
          expect(err.toLowerCase(), isNot(contains('zzfake')));
        }
        final (c2, _, e2) = await cli(['--keep-key']);
        expect(c2, 2);
        expect(e2, contains('Usage'));
      });

      test('the committed keep_keys.txt parses and holds no usernames', () {
        final lines = File('tool/keep_keys.txt').readAsLinesSync();
        for (final l in lines.map((e) => e.trim())) {
          if (l.isEmpty || l.startsWith('#')) continue;
          expect(RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,59}$').hasMatch(l), isTrue);
        }
      });
    });
  });
}
