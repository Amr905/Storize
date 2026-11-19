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

    test('unknown safe-word key next to a known key is kept', () {
      final j = _body(
        _run({
          'pk': '1234567890',
          'brand_new_field': 1,
          'zzfake_nour.k': 2,
        }),
      );
      expect(j.containsKey('brand_new_field'), isTrue);
      expect(j.keys.where((k) => k.startsWith('key_')), hasLength(1));
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

    test('GraphQL root fields under data are kept, elsewhere they are not', () {
      final j = _body(
        _run({
          'data': {'xdt_api__v1__feed__user_timeline_graphql_connection': 1},
          'other': {'xdt_zzfake_user': 1},
        }),
      );
      expect(
        (j['data'] as Map).keys.single,
        'xdt_api__v1__feed__user_timeline_graphql_connection',
      );
      expect(
        (j['other'] as Map).keys.single,
        startsWith('key_'),
        reason: 'xdt_ names only count directly under data',
      );
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

    test('identifier-shaped values pass, including GraphQL typenames', () {
      final j = enums({
        'status': 'ok',
        'product_type': 'clips',
        'type': 'XDTGraphImage',
        '__typename': 'XDTGraphImage',
        'audience': 'MediaAudience_default',
      });
      expect(j['status'], 'ok');
      expect(j['product_type'], 'clips');
      expect(j['type'], 'XDTGraphImage');
      expect(j['__typename'], 'XDTGraphImage');
      expect(j['audience'], 'MediaAudience_default');
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
}
