// QA round 4 adversarial probes (second file). All data is FAKE.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sanitize_har.dart';

const _u = 'https://www.instagram.com/api/v1/friendships/show_many/';

String _har(
  Object? body, {
  String url = _u,
  List<Map<String, String>> headers = const [],
}) => jsonEncode({
  'log': {
    'entries': [
      {
        'request': {'method': 'GET', 'url': url, 'headers': headers},
        'response': {
          'status': 200,
          'content': {'mimeType': 'application/json', 'text': jsonEncode(body)},
        },
      },
    ],
  },
});

/// Output text or null when the run failed closed (acceptable: nothing written).
String? _out(
  Object? body, {
  String url = _u,
  List<Map<String, String>> headers = const [],
}) {
  final o = sanitizeHar(_har(body, url: url, headers: headers));
  return o.ok ? o.files.values.join('\n') : null;
}

void noLeak(
  String name,
  Object? body, {
  String? skip,
  String? url,
  List<Map<String, String>> headers = const [],
}) {
  test(name, skip: skip, () {
    final out = _out(body, url: url ?? _u, headers: headers);
    if (out != null) expect(out.toLowerCase(), isNot(contains('zzfake')));
  });
}

const _qa14 = 'QA-14: snake_case key kept next to an allowlisted sibling';
const _qa15 =
    'QA-15: username equal to an allowlisted key makes the whole map keep its keys';

void main() {
  group('1 snake_case + allowlisted sibling', () {
    noLeak('pk sibling', {
      'pk': '1',
      'zzfake_nour': {'a': 1},
    }, skip: _qa14);
    noLeak('unknown map seen_by with a username that is an allowlisted word', {
      'seen_by': {
        'user': {'a': 1},
        'zzfake_nour': {'a': 1},
      },
    }, skip: _qa15);
    noLeak('likers_map keyed by usernames, all unknown', {
      'likers_map': {
        'zzfake_nour': {'pk': '1234567890'},
        'zzfake_two': {'pk': '1234567891'},
      },
    }, skip: _qa14);
    noLeak('mentions keyed by username, values are objects with known keys', {
      'mentions': {
        'zzfake_nour': {'username': 'x', 'pk': '1234567890'},
      },
    });
    noLeak('tagged_users map keyed by username, values scalar', {
      'tagged_users': {'zzfake_nour': 1, 'zzfake_two': 2},
    });
    noLeak('all-unknown siblings in a map, username is lower snake', {
      'zzfake_a': 1,
      'zzfake_b': 2,
    });
    noLeak('typical story viewers map: count sibling plus usernames', {
      'viewers': {
        'count': 2,
        'zzfake_nour': {'seen': true},
        'zzfake_two': {'seen': true},
      },
    }, skip: _qa14);
    noLeak('username dotted next to known sibling', {
      'id': '1',
      'zzfake.nour': 1,
    });
    noLeak('username key under data with xdt-looking name', {
      'data': {
        'xdt_zzfake_nour': {'id': '1'},
      },
    }, skip: 'QA-16: any xdt_/xig_ key directly under data is kept');
  });

  group('2 usernames shaped like allowlisted keys', () {
    noLeak('user literally named username inside users map', {
      'users': {
        'username': {'pk': '1234567890', 'full_name': 'zzfake name'},
      },
    });
    noLeak('user named id next to numeric-id keys in unknown map', {
      'zzmap': {
        'id': {'a': 1},
        '1234567890': {'a': 1},
      },
    });
    test('value under a kept key named username is replaced', () {
      final out = _out({
        'user': {
          'username': 'zzfake_nour',
          'full_name': 'zzfake Name',
          'profile_pic_url': 'https://scontent-x.cdninstagram.com/v/zzfake.jpg',
          'biography': 'zzfake bio',
          'caption': {'text': 'zzfake caption'},
        },
      })!;
      expect(out.toLowerCase(), isNot(contains('zzfake')));
      expect(out, contains('<str:'));
    });
    test(
      'enum keys with username-looking values are kept (known gap, low)',
      () {
        final out = _out({
          'user': {
            'pk': '1',
            'type': 'zzfake_nour',
            'status': 'zzfake_nour',
            'kind': 'zzfake',
          },
        });
        expect(out, isNotNull);
        expect(out!.toLowerCase(), isNot(contains('zzfake')));
      },
      skip: 'QA-17: identifier-shaped value under type/status/kind/audience is kept',
    );
  });

  group('3 values everywhere', () {
    noLeak('arrays of strings under kept keys', {
      'users': ['zzfake_a'],
      'items': ['zzfake_b'],
      'usertags': {
        'in': [
          {
            'user': {'username': 'zzfake_c', 'full_name': 'zzfake d'},
          },
        ],
      },
    });
    noLeak('caption text, nested list', {
      'items': [
        {
          'caption': {'text': 'zzfake #tag @zzfake_x', 'pk': '1234567890'},
        },
      ],
    });
    noLeak('username as value of numeric-looking idKey string', {
      'pk': 'zzfake_nour',
      'id': 'zzfake_nour',
      'user_id': 'zzfake',
    });
    noLeak('username inside an url value', {
      'profile_pic_url':
          'https://scontent-x.cdninstagram.com/zzfake_nour/a.jpg',
    });
    noLeak('username in an instagram profile url on a non-url key', {
      'link': 'https://www.instagram.com/zzfake_nour/',
    });
    noLeak('username with whitespace url-ish', {
      'text': 'see https://instagram.com/zzfake',
    });
    noLeak('user id as a 10-digit int under non-id key', {
      'actor': 1234567890,
      'zzfake_marker': 1,
    }, skip: 'covered below');
    test(
      '10-digit user id as int under non-id key (QA-18, low)',
      () {
        final out = _out({'mentioned': 1234567890, 'pk': '1'})!;
        expect(out, isNot(contains('1234567890')));
      },
      skip: 'QA-18: ints under keys not ending in id/pk/owner are kept unless 13+ digits',
    );
    noLeak('map key inside a dynamic map named like a dynamic parent', {
      'users': {
        'zzfake_a': {
          'reels': {
            'zzfake_b': {'a': 1},
          },
        },
      },
    });
    noLeak('username equals dynamic parent word', {
      'users': {
        'reels': {
          'zzfake_b': {'a': 1},
        },
      },
    });
  });

  group('4 header and query name residual', () {
    test('query name that looks like a username is kept', () {
      final out = _out({'status': 'ok'}, url: '$_u?zzfake_nour=1');
      expect(out, isNotNull);
      expect(out!.toLowerCase(), isNot(contains('zzfake')));
    }, skip: 'QA-19 (accepted residual): lowercase query/header name passes');
    test('header name with a username shape is kept (accepted residual)', () {
      final out = _out(
        {'status': 'ok'},
        headers: [
          {'name': 'zzfake-nour', 'value': 'x'},
        ],
      );
      expect(out!.toLowerCase(), isNot(contains('zzfake')));
    }, skip: 'QA-19');
    noLeak('query name with dot/digit/uppercase', {
      'status': 'ok',
    }, url: '$_u?ZZfake.nour=1&zzfake9=2&zz.fake=1');
    noLeak('query name that is an email or url', {
      'status': 'ok',
    }, url: '$_u?zzfake%40x.com=1');
    noLeak(
      'query value username (ok) and bare flag name (QA-19)',
      {
        'status': 'ok',
      },
      url: '${_u}web_profile_info/?username=zzfake_nour&zzfake',
      skip: 'QA-19 accepted residual: bare lowercase query name',
    );
    noLeak('path segments', {
      'status': 'ok',
    }, url: 'https://www.instagram.com/api/v1/zzfake_nour/info/');
    noLeak(
      'header values',
      {'status': 'ok'},
      headers: [
        {'name': 'x-ig-app-id', 'value': 'zzfake'},
        {'name': 'accept', 'value': 'zzfake'},
        {'name': 'content-type', 'value': 'zzfake'},
        {'name': 'user-agent', 'value': 'zzfake'},
      ],
      skip: 'QA-22 (low): accept/content-type keep any plain word',
    );
  });

  group('5 coarseUserAgent', () {
    const uas = {
      'Mozilla/5.0 (Linux; Android 13; SM-S918B Build/TP1A.220624.014; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.144 Mobile Safari/537.36':
          'Chrome/120 (Android, WebView)',
      'Instagram 300.0.0.29.110 Android (33/13; 480dpi; 1080x2340; samsung; SM-S918B; dm3q; qcom; en_US; 524528404)':
          'Instagram/300 (Android)',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/21C62 Instagram 312.0.1.18.115 (iPhone14,5; iOS 17_2; en_US; en-US; scale=3.00; 1170x2532; 538588338)':
          'Instagram/312 (iOS)',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1':
          'Safari/17 (iOS)',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0':
          'Edge/120 (Windows)',
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36':
          'Chrome/120 (Android)',
    };
    uas.forEach((ua, want) {
      test('coarse: $want', () {
        final got = coarseUserAgent(ua);
        expect(got, want);
      });
    });
    test('no digits beyond the major version, no device/build tokens', () {
      for (final ua in uas.keys) {
        final got = coarseUserAgent(ua);
        expect(
          got,
          isNot(
            matches(
              RegExp(
                r'SM-|Build|TP1A|dm3q|qcom|iPhone14|1170|524528404|\d{4,}',
              ),
            ),
          ),
        );
      }
    });
    test('UA that embeds a username and an unknown family', () {
      expect(
        coarseUserAgent('zzfake_nour/1.0 (Linux; Android 13; Pixel 7)'),
        '<ua>',
      );
      expect(
        coarseUserAgent('Mozilla/5.0 zzfake Chrome/120.1.2.3 foo')
            .contains('zzfake'),
        isFalse,
      );
    });
  });

  group('6 fail closed', () {
    test(
      'username-shaped token in a place no rule covers: bodyNote/status etc',
      () {
        // mimeType and status are shape-checked; method is shape-checked; host is IG-only.
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
        final all = o.files.values.join('\n').toLowerCase();
        expect(all, isNot(contains('zzfake')));
      },
      skip:
          'QA-23 (info): method is upper-cased before its shape check; '
          'response mimeType keeps any word-shaped text',
    );
    test('scan itself does not detect a plain username (documented limitation)', () {
      // The final scan only looks for secrets/emails/phones/tokens, not names.
      expect(findLeaks('{"zzfake_nour": 1}'), isEmpty);
    });
    test('scan catches planted secrets, signed urls, emails', () {
      expect(findLeaks('{"a":"https://x.example/a.jpg?oh=1"}'), isNotEmpty);
      expect(findLeaks('{"a":"zzfake@example.com"}'), isNotEmpty);
      expect(findLeaks('{"sessionid":"abcdef123"}'), isNotEmpty);
    });
  });

  group('7 survival of TECH_SPEC 4.1 fields', () {
    test('IG-1..IG-5 field names and the failure map', () {
      final fixtures = <String, Object?>{
        'ig1': {
          'data': {
            'user': {
              'id': '1234567890',
              'username': 'zzfake',
              'full_name': 'x',
              'is_private': false,
              'followed_by_viewer': false,
              'blocked_by_viewer': false,
              'profile_pic_url': 'https://scontent-x.cdninstagram.com/a.jpg',
            },
          },
        },
        'ig2': {
          'reels': {
            '1234567890': {
              'items': [
                {
                  'pk': '1234567890',
                  'taken_at': 1700000000,
                  'expiring_at': 1700086400,
                  'media_type': 2,
                  'image_versions2': {
                    'candidates': [
                      {
                        'width': 1,
                        'height': 2,
                        'url': 'https://x.cdninstagram.com/a.jpg',
                      },
                    ],
                  },
                  'video_versions': [
                    {
                      'width': 1,
                      'height': 2,
                      'type': 101,
                      'url': 'https://x.cdninstagram.com/a.mp4',
                    },
                  ],
                  'video_duration': 5.5,
                  'audience': 'besties',
                  'story_link_stickers': [
                    {'x': 1},
                  ],
                },
              ],
            },
          },
        },
        'ig3': {
          'user': {'username': 'zzfake', 'is_private': true},
          'status': 'ok',
        },
        'ig4': {
          'user': {'pk': '1234567890'},
        },
        'ig5': {
          'items': [
            {
              'pk': '1234567890',
              'code': 'AbC',
              'taken_at': 1,
              'media_type': 8,
              'product_type': 'clips',
              'carousel_media': [
                {'media_type': 1},
              ],
              'caption': {'text': 't'},
              'image_versions2': {'candidates': <Object?>[]},
              'video_versions': <Object?>[],
            },
          ],
          'more_available': true,
          'num_results': 1,
          'next_max_id': '1234567890_1',
        },
      };
      final o = sanitizeHar(_har(fixtures));
      expect(o.ok, isTrue);
      final all = o.files.values.join('\n');
      for (final k in [
        'id',
        'username',
        'full_name',
        'is_private',
        'followed_by_viewer',
        'blocked_by_viewer',
        'profile_pic_url',
        'items',
        'pk',
        'taken_at',
        'expiring_at',
        'media_type',
        'image_versions2',
        'candidates',
        'video_versions',
        'video_duration',
        'audience',
        'story_link_stickers',
        'code',
        'product_type',
        'carousel_media',
        'caption',
        'text',
        'more_available',
        'num_results',
        'next_max_id',
      ]) {
        expect(all, contains('"$k"'), reason: 'field $k missing');
      }
      expect(all, contains('"audience": "besties"'));
      expect(all, contains('"product_type": "clips"'));
    });
    test(
      'failure-map values (login_required, checkpoint_required, ...) survive',
      () {
        final o = sanitizeHar(
          _har({
            'message': 'login_required',
            'status': 'fail',
            'error_type': 'checkpoint_required',
            'require_login': true,
            'spam': true,
          }),
        );
        final all = o.files.values.join('\n');
        expect(all, contains('login_required'));
      },
      skip: 'QA-20: message/error_type values are replaced, so the failure map cannot be observed',
    );
    test('camelCase GraphQL keys next to known keys', () {
      final o = sanitizeHar(
        _har({'id': '1234567', 'profilePicUrl': 'x', 'fullName': 'y'}),
      );
      expect(o.files.values.join('\n'), contains('profilePicUrl'));
    }, skip: 'QA-21 (info): camelCase keys become key_N');
  });
}
