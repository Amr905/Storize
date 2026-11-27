// FR-77 (T-054): caption, location and tagged usernames. Synthetic ZZFAKE_
// data only.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/mapper/mapper.dart';

const _media = MediaMapper();

Node _n(Map<String, Object?> m) => Node.root(m, 'item');

Map<String, Object?> _base(Map<String, Object?> extra) => {
  'pk': 'ZZFAKE_p',
  'code': 'ZZFAKE_code',
  'media_type': 1,
  'taken_at': 1800000000,
  'image_versions2': {
    'candidates': [
      {'url': 'u1', 'width': 10, 'height': 10},
    ],
  },
  ...extra,
};

Map<String, Object?> _tag(Object? name) => {
  'user': {'username': name},
};

void main() {
  test('post keeps caption, location and tags', () {
    final c = _media.post(
      _n(
        _base({
          'caption': {'text': 'ZZFAKE_caption'},
          'location': {'name': 'ZZFAKE_place', 'pk': '1'},
          'usertags': {
            'in': [_tag('zzfake_a'), _tag('zzfake_b')],
          },
        }),
      ),
    );
    expect(c.caption, 'ZZFAKE_caption');
    expect(c.locationName, 'ZZFAKE_place');
    expect(c.taggedUsernames, ['zzfake_a', 'zzfake_b']);
  });

  test('absent fields give null and an empty list', () {
    final c = _media.post(_n(_base({})));
    expect(c.caption, isNull);
    expect(c.locationName, isNull);
    expect(c.taggedUsernames, isEmpty);
  });

  test('odd types never fail the item', () {
    for (final odd in <Map<String, Object?>>[
      {'caption': 'ZZFAKE_str', 'location': 5, 'usertags': 'x'},
      {
        'caption': {'text': 7},
        'location': {'name': <String>[]},
        'usertags': {'in': 3},
      },
      {
        'caption': null,
        'location': {'name': null},
        'usertags': {
          'in': [
            null,
            5,
            {'user': 'x'},
            _tag(null),
            _tag(''),
            _tag(9),
          ],
        },
      },
    ]) {
      final c = _media.post(_n(_base(odd)));
      expect(c.locationName, isNull, reason: '$odd');
      expect(c.taggedUsernames, isEmpty, reason: '$odd');
    }
  });

  test('carousel merges child tags, dedupes and caps at 50', () {
    final child = {
      'pk': 'ZZFAKE_c',
      'media_type': 1,
      'image_versions2': {
        'candidates': [
          {'url': 'u', 'width': 1, 'height': 1},
        ],
      },
    };
    final c = _media.post(
      _n(
        _base({
          'media_type': 8,
          'usertags': {
            'in': [_tag('zzfake_a')],
          },
          'carousel_media': [
            {
              ...child,
              'usertags': {
                'in': [_tag('ZZFAKE_A'), _tag('zzfake_b')],
              },
            },
            {
              ...child,
              'usertags': {
                'in': [for (var i = 0; i < 80; i++) _tag('zzfake_t$i')],
              },
            },
          ],
        }),
      ),
    );
    expect(c.taggedUsernames.take(2), ['zzfake_a', 'zzfake_b']);
    expect(c.taggedUsernames, hasLength(50));
    expect(c.taggedUsernames.toSet(), hasLength(50));
  });

  test('story keeps location and tags, highlight also the caption', () {
    final raw = _base({
      'expiring_at': 1800086400,
      'caption': {'text': 'ZZFAKE_hl'},
      'location': {'name': ' ZZFAKE_loc '},
      'usertags': {
        'in': [_tag('zzfake_a')],
      },
    });
    final s = _media.story(_n(raw))!;
    expect(s.locationName, 'ZZFAKE_loc');
    expect(s.taggedUsernames, ['zzfake_a']);
    final h = _media.highlight(_n(raw), highlightId: 'ZZFAKE_h', order: 0)!;
    expect(h.caption, 'ZZFAKE_hl');
    expect(h.locationName, 'ZZFAKE_loc');
    expect(h.taggedUsernames, ['zzfake_a']);
  });

  test('toString omits details', () {
    final c = _media.post(
      _n(
        _base({
          'caption': {'text': 'ZZFAKE_secret'},
          'location': {'name': 'ZZFAKE_place'},
          'usertags': {
            'in': [_tag('zzfake_a')],
          },
        }),
      ),
    );
    expect(c.toString(), isNot(contains('ZZFAKE_secret')));
    expect(c.toString(), isNot(contains('ZZFAKE_place')));
    expect(c.toString(), isNot(contains('zzfake_a')));
  });
}
