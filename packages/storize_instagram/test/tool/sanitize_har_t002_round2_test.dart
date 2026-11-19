// T-002 round 2: float/location rules, latest_reel_media rule, CDN host rule.
// FAKE data only. Coordinates, names and hosts below are invented.
// ignore_for_file: avoid_dynamic_calls
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

SanitizeOutcome _run(Object? body, {Set<String> keep = const {}}) {
  final o = sanitizeHar(_har(body), keepKeys: keep);
  expect(o.ok, isTrue, reason: '${o.leaks}');
  return o;
}

dynamic _body(SanitizeOutcome o) => jsonDecode(
  o.files.entries.firstWhere((e) => e.key.startsWith('bodies/')).value,
);

String _all(SanitizeOutcome o) => o.files.values.join('\n');

/// Collects every double found anywhere in [j].
List<double> _doubles(dynamic j) => [
  if (j is double) j,
  if (j is Map)
    for (final v in j.values) ..._doubles(v),
  if (j is List)
    for (final v in j) ..._doubles(v),
];

void main() {
  group('B2 location floats', () {
    test('lat/lng/latitude/longitude keys become null (float and int)', () {
      final o = _run({
        'lat': 12.345678901,
        'lng': 45.678901234,
        'latitude': 12.345678901,
        'longitude': 7, // an int is also a coordinate
      });
      // The keys themselves are renamed to key_N; only the values matter.
      final b = _body(o) as Map;
      expect(b, hasLength(4));
      expect(b.values, everyElement(isNull));
      expect(_all(o), isNot(contains('12.3456')));
    });

    test('location_* keys become null', () {
      final b =
          _body(_run({'location_pk': 1.23456789, 'location_x': 5})) as Map;
      expect(b, hasLength(2));
      expect(b.values, everyElement(isNull));
    });

    test('__typename containing Location: floats under renamed keys', () {
      final o = _run({
        'zzfake_loc': {
          '__typename': 'XDTLocationDict',
          'zzfake_a': 12.345678901,
          'zzfake_b': 45.678901234,
          'zzfake_c': {
            'zzfake_d': [1.5, 2.25],
          },
        },
      });
      expect(_doubles(_body(o)), isEmpty);
      final t = _all(o);
      expect(t, isNot(contains('12.3456')));
      expect(t, isNot(contains('45.6789')));
      expect(t, contains('location_floats_nulled'));
    });

    test('typename match is case-insensitive and not tied to XDT', () {
      final b = _body(
        _run({
          'zzfake_loc': {'__typename': 'GraphLocationThing', 'zzfake_a': 0.5},
        }),
      );
      expect(_doubles(b), isEmpty);
    });

    test('a location subtree is detected by its ORIGINAL key name', () {
      // `location` is not on the key allowlist, so it becomes key_N. The rule
      // must still fire. No __typename here.
      final b = _body(
        _run({
          'location': {
            'zzfake_a': 12.345678901,
            'zzfake_n': [3.5, 4.5],
            'zzfake_o': {'zzfake_p': 9.87654321},
          },
        }),
      );
      expect(_doubles(b), isEmpty);
    });

    test('floats next to (not inside) a location object are only rounded', () {
      final b = _body(
        _run({
          'zzfake_loc': {'__typename': 'XDTLocationDict', 'zzfake_a': 1.5},
          'zzfake_other': 17.456789012,
        }),
      );
      expect(_doubles(b), [17.46]);
    });

    test('ints under a location object are not floats and stay', () {
      final b = _body(
        _run({
          'zzfake_loc': {'__typename': 'XDTLocationDict', 'zzfake_a': 5},
        }),
      );
      expect((b['key_1'] as Map).values.whereType<int>(), contains(5));
    });
  });

  group('L2 generic float rule', () {
    test('rounds to at most 2 decimals', () {
      final b = _body(
        _run({'x': 17.456789012345678, 'y': 0.1234567, 'z': 3.0}),
      );
      final d = _doubles(b);
      expect(d, containsAll(<double>[17.46, 0.12, 3]));
    });

    test('rounds a tiny value to 0.0 and keeps it', () {
      expect(_doubles(_body(_run({'x': 1e-7}))), [0.0]);
    });

    test('exponent-form values (huge) are dropped to null', () {
      final o = _run({'x': 1.5e30});
      expect(_doubles(_body(o)), isEmpty);
      expect(_all(o), contains('floats_nulled'));
    });

    test('plain ints are untouched', () {
      final b = _body(_run({'x': 123, 'y': -4}));
      expect(b.values.whereType<int>().toSet(), {123, -4});
    });

    test('no output float has more than 4 decimals', () {
      final o = _run({
        'a': [0.123456789, 99.99999, 1234567.891234, 0.005, 0.015],
      });
      for (final d in _doubles(_body(o))) {
        final s = d.toString();
        expect(s.contains('e'), isFalse);
        expect(s.split('.').last.length, lessThanOrEqualTo(4), reason: s);
      }
    });
  });

  group('L1 latest_reel_media', () {
    test('kept at the profile root user and the story reel only', () {
      final o = _run(
        {
          'data': {
            'user': {'latest_reel_media': 1700000001, 'username': 'zzfake'},
            'xdt_api__v1__feed__reels_media': {
              'reels_media': [
                {
                  'latest_reel_media': 1700000002,
                  'user': {'latest_reel_media': 1700000003},
                  'items': [
                    {
                      'user': {'latest_reel_media': 1700000004},
                    },
                  ],
                },
              ],
            },
          },
        },
        keep: {'xdt_api__v1__feed__reels_media'},
      );
      final b = _body(o);
      expect(b['data']['user']['latest_reel_media'], 1700000001);
      final reel =
          b['data']['xdt_api__v1__feed__reels_media']['reels_media'][0];
      expect(reel['latest_reel_media'], 1700000002);
      expect(reel['user']['latest_reel_media'], isNull);
      expect(reel['items'][0]['user']['latest_reel_media'], isNull);
      expect(_all(o), contains('latest_reel_media_nulled'));
    });

    test('nulled for commenters, tagged users and post authors', () {
      final b = _body(
        _run({
          'data': {
            'zzfake_edges': [
              {
                'node': {
                  'user': {'latest_reel_media': 1700000010},
                  'owner': {'latest_reel_media': 1700000011},
                  'preview_comments': [
                    {
                      'user': {'latest_reel_media': 1700000012},
                    },
                  ],
                },
              },
            ],
            'viewer': {
              'user': {'latest_reel_media': 1700000013},
            },
          },
        }),
      );
      expect(
        _ints(b),
        isNot(
          anyOf(
            contains(1700000010),
            contains(1700000011),
            contains(1700000012),
            contains(1700000013),
          ),
        ),
      );
    });

    test('the keep path is exact: nested data.user is not kept', () {
      final b = _body(
        _run({
          'data': {
            'user': {
              'friends': [
                {'latest_reel_media': 1700000020},
              ],
              'zzfake': {
                'user': {'latest_reel_media': 1700000021},
              },
            },
          },
        }),
      );
      expect(_ints(b), isNot(contains(1700000020)));
      expect(_ints(b), isNot(contains(1700000021)));
    });

    test('a string value is not touched by the numeric rule', () {
      final b = _body(_run({'latest_reel_media': 'zzfake'}));
      expect(
        _all(_run({'latest_reel_media': 'zzfake'})),
        isNot(contains('zzfake')),
      );
      expect(b['latest_reel_media'], isA<String>());
    });
  });

  group('B1 CDN hosts', () {
    String hosts(String h) {
      final o = _run({
        'a': {'url': 'https://$h/v/t51/a/b/c.jpg?oh=1&oe=2'},
      });
      final t = _all(o);
      final m = RegExp('<url host=([^ >]+) path_shape').firstMatch(t);
      expect(m, isNotNull, reason: h);
      return m!.group(1)!;
    }

    test('edge and region labels are dropped', () {
      expect(hosts('instagram.fxyz19-4.fna.fbcdn.net'), 'instagram.fbcdn.net');
      expect(hosts('scontent.fxyz19-4.fna.fbcdn.net'), 'scontent.fbcdn.net');
      expect(hosts('video.fxyz19-1.fna.fbcdn.net'), 'video.fbcdn.net');
      expect(hosts('scontent-xyz1-1.cdninstagram.com'), 'cdninstagram.com');
      expect(hosts('static.cdninstagram.com'), 'static.cdninstagram.com');
    });

    test('non-generic first label collapses to the registrable domain', () {
      expect(hosts('edge-abc1-1.xx.fbcdn.net'), 'fbcdn.net');
      expect(hosts('fbcdn.net'), 'fbcdn.net');
    });

    test('many labels, upper case and a port are handled', () {
      expect(hosts('scontent.a.b.c.d.fbcdn.net'), 'scontent.fbcdn.net');
      expect(hosts('SCONTENT.FXYZ1-1.FNA.FBCDN.NET:443'), 'scontent.fbcdn.net');
    });

    test('look-alike domains are not CDN hosts', () {
      expect(hosts('scontent.evil-fbcdn.net'), 'external');
      expect(hosts('fbcdn.net.example.org'), 'external');
    });

    test('no edge label survives anywhere in the outputs', () {
      final o = _run({
        'a': {'url': 'https://instagram.fxyz19-4.fna.fbcdn.net/v/c.mp4'},
        'b': {
          'profile_pic_url': 'https://scontent-xyz1-1.cdninstagram.com/c.jpg',
        },
      });
      expect(_all(o), isNot(contains('fxyz19')));
      expect(_all(o), isNot(contains('xyz1')));
    });
  });
}

List<int> _ints(dynamic j) => [
  if (j is int) j,
  if (j is Map)
    for (final v in j.values) ..._ints(v),
  if (j is List)
    for (final v in j) ..._ints(v),
];
