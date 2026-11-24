// QA round 2 (T-002): adversarial probes of the B1/B2/L1 sanitizer rules.
// FAKE data only: every marker is ZZFAKE or an invented number.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sanitize_har.dart';

const _u = 'https://www.instagram.com/api/v1/x/';

String _har(Object? body) => jsonEncode({
  'log': {
    'entries': [
      {
        'request': {'method': 'GET', 'url': _u, 'headers': <Object?>[]},
        'response': {
          'status': 200,
          'content': {'mimeType': 'application/json', 'text': jsonEncode(body)},
        },
      },
    ],
  },
});

SanitizeOutcome _run(Object? body) {
  final o = sanitizeHar(_har(body));
  expect(o.ok, isTrue, reason: '${o.leaks}');
  return o;
}

String _bodyText(SanitizeOutcome o) =>
    o.files.entries.firstWhere((e) => e.key.startsWith('bodies/')).value;

String _all(SanitizeOutcome o) => o.files.values.join('\n');

/// Every number token in [s] that has an exponent or 3 or more decimals.
List<String> _precise(String s) =>
    RegExp(r'-?\d+\.\d{3,}|-?\d+(?:\.\d+)?[eE][-+]?\d+')
        .allMatches(s)
        .map((m) => m.group(0)!)
        .toList();

void main() {
  group('location under other keys and shapes (B2)', () {
    test('renamed key, no typename: no 3+ decimal coordinate survives', () {
      final o = _run({
        'zzfake_place': {'zzfake_x': 31.2345678, 'zzfake_y': 29.8765432},
      });
      expect(_precise(_bodyText(o)), isEmpty);
    });

    test('lat/lng as strings do not survive', () {
      final o = _run({
        'lat': '31.2345678',
        'lng': '29.8765432',
        'location': {'latitude': '31.2345678', 'zzfake': '29.8765432'},
      });
      expect(_all(o), isNot(contains('31.2345678')));
      expect(_all(o), isNot(contains('29.8765432')));
    });

    test('nested location lists', () {
      final o = _run({
        'location': [
          {
            'zzfake': [
              [31.2345678, 29.8765432],
              {'zzfake2': 31.2345678},
            ],
          },
        ],
        'locations': [
          [31.2345678, 29.8765432],
        ],
      });
      expect(_all(o), isNot(contains('31.2345')));
      expect(_all(o), isNot(contains('29.8765')));
    });

    test('exponent floats are dropped, also inside and outside location', () {
      final o = _run({
        'zzfake_a': 1.2345678e-5,
        'zzfake_b': 3.1e22,
        'zzfake_c': -2.5E-7,
        'location': {'zzfake_d': 1.2345678e-5},
      });
      final t = _bodyText(o);
      expect(_precise(t), isEmpty, reason: t);
      expect(t, isNot(contains('e-')));
      expect(t, isNot(contains('E-')));
    });

    test('float rounded to 2 decimals, long ones dropped, ints untouched', () {
      final o = _run({'zzfake_a': 0.123456, 'zzfake_b': 1.5, 'zzfake_c': 42});
      final b = jsonDecode(_bodyText(o)) as Map;
      final v = b.values.toList();
      expect(v, contains(0.12));
      expect(v, contains(1.5));
      expect(v, contains(42));
    });
  });

  group('look-alike CDN hosts (B1)', () {
    const hosts = [
      'https://scontent.fbcdn.net.zzfake.example/v/t51/a.jpg',
      'https://scontent.fbcdn.net@zzfake.example/v/t51/a.jpg',
      'https://zzfake.example/scontent.fbcdn.net/a.jpg',
      'https://xscontent.fbcdn.net/v/a.jpg',
      'https://scontent-zzfake1-1.xx.fbcdn.net/v/a.jpg',
      'https://zzfake1.scontent.fbcdn.net/v/a.jpg',
      'https://scontent.cdninstagram.com.zzfake.example/a.jpg',
      'https://notfbcdn.net/a.jpg',
      'https://fbcdn.net.zzfake.example/a.jpg',
      'https://SCONTENT-ZZFAKE1-1.XX.FBCDN.NET/a.jpg',
      'https://scontent.fbcdn.net:8443/a.jpg',
      'https://zzfake.fbcdn.net/a.jpg',
      'https://zzfake.cdninstagram.com/a.jpg',
      'https://instagram.zzfake1-1.fna.fbcdn.net/a.jpg',
    ];

    for (final h in hosts) {
      test('no ZZFAKE or edge label survives: ${h.replaceAll('ZZ', 'zz')}', () {
        final o = _run({
          'url': h,
          'zzfake_list': <Object?>[h],
        });
        final t = _all(o).toLowerCase();
        expect(t, isNot(contains('zzfake')));
        expect(t, isNot(contains('zzfake1')));
        expect(t, isNot(contains('a.jpg')));
        // Every placeholder host is one of the generic forms.
        final hs = RegExp('<url host=([^ >]*)')
            .allMatches(t)
            .map((m) => m.group(1)!)
            .toSet();
        const ok = {
          'scontent.fbcdn.net',
          'instagram.fbcdn.net',
          'static.fbcdn.net',
          'video.fbcdn.net',
          'fbcdn.net',
          'scontent.cdninstagram.com',
          'instagram.cdninstagram.com',
          'static.cdninstagram.com',
          'video.cdninstagram.com',
          'cdninstagram.com',
          'external',
          'www.instagram.com',
          'instagram.com',
          'l.instagram.com',
        };
        expect(hs.difference(ok), isEmpty, reason: '$hs');
      });
    }
  });

  group('latest_reel_media at depth (L1)', () {
    // The raw-key paths are what the rule reads, so the keys must be allowed.
    SanitizeOutcome run(Object? body) => sanitizeHar(
      _har(body),
      keepKeys: const {
        'data',
        'user',
        'friend',
        'zzfake_wrap',
        'xdt_api__v1__feed__reels_media',
        'reels_media',
        'edges',
        'node',
        'items',
      },
    );

    String lrm(SanitizeOutcome o) {
      final t = _bodyText(o);
      return t;
    }

    test(r'kept at $.data.user and the story reels_media[] only', () {
      final o = run({
        'data': {
          'user': {
            'latest_reel_media': 1700000123,
            'friend': {'latest_reel_media': 1700000456},
          },
          'xdt_api__v1__feed__reels_media': {
            'reels_media': [
              {
                'latest_reel_media': 1700000789,
                'user': {'latest_reel_media': 1700000999},
                'items': [
                  {'latest_reel_media': 1700000888},
                ],
              },
            ],
          },
        },
      });
      expect(o.ok, isTrue, reason: '${o.leaks}');
      final t = lrm(o);
      expect(t, contains('1700000123'));
      expect(t, contains('1700000789'));
      expect(t, isNot(contains('1700000456')));
      expect(t, isNot(contains('1700000999')));
      expect(t, isNot(contains('1700000888')));
    });

    test('not kept when the path only ends like the allowed one', () {
      final o = run({
        'zzfake_wrap': {
          'data': {
            'user': {'latest_reel_media': 1700000321},
          },
        },
        'data': {
          'edges': [
            {
              'node': {
                'user': {'latest_reel_media': 1700000654},
              },
            },
          ],
          'zzfake_wrap': {
            'user': {'latest_reel_media': 1700000777},
          },
        },
      });
      expect(o.ok, isTrue, reason: '${o.leaks}');
      final t = lrm(o);
      expect(t, isNot(contains('1700000321')));
      expect(t, isNot(contains('1700000654')));
      expect(t, isNot(contains('1700000777')));
    });
  });
}
