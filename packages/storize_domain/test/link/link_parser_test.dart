import 'dart:convert';

import 'package:storize_domain/storize_domain.dart';
import 'package:test/test.dart';

String _short(String payload) =>
    base64Url.encode(utf8.encode(payload)).replaceAll('=', '');

void main() {
  ParsedLink? p(String s) => LinkParser.parse(s);

  group('stories', () {
    test('a story link, with a trailing slash or not', () {
      const want = ParsedLink(
        kind: LinkKind.story,
        username: 'zed.x_1',
        mediaPk: '3000000000000000001',
      );
      expect(
        p('https://www.instagram.com/stories/zed.x_1/3000000000000000001/'),
        want,
      );
      expect(
        p('https://instagram.com/stories/zed.x_1/3000000000000000001'),
        want,
      );
    });

    test('the query string is dropped (igsh)', () {
      expect(
        p('https://www.instagram.com/stories/zed/3001/?igsh=ZZFAKE_abc&utm=1'),
        const ParsedLink(
          kind: LinkKind.story,
          username: 'zed',
          mediaPk: '3001',
        ),
      );
    });

    test('hosts: www, m and bare, any case, with or without a scheme', () {
      for (final u in [
        'http://m.instagram.com/stories/zed/3001/',
        'instagram.com/stories/zed/3001/',
        'www.instagram.com/stories/zed/3001/',
        'HTTPS://WWW.INSTAGRAM.COM/stories/zed/3001/',
      ]) {
        expect(p(u)?.kind, LinkKind.story, reason: u);
      }
    });

    test('a story link without a media id is not supported', () {
      expect(p('https://www.instagram.com/stories/zed/'), isNull);
      expect(p('https://www.instagram.com/stories/zed/abc/'), isNull);
    });
  });

  group('posts and reels', () {
    test('/p/, /reel/ and /reels/', () {
      expect(
        p('https://www.instagram.com/p/ZZFAKE_c1/?igsh=x'),
        const ParsedLink(kind: LinkKind.post, shortcode: 'ZZFAKE_c1'),
      );
      expect(
        p('https://www.instagram.com/reel/ZZFAKE-c2/'),
        const ParsedLink(kind: LinkKind.reel, shortcode: 'ZZFAKE-c2'),
      );
      expect(
        p('https://instagram.com/reels/ZZFAKE_c3'),
        const ParsedLink(kind: LinkKind.reel, shortcode: 'ZZFAKE_c3'),
      );
    });

    test('/<username>/p/<shortcode>/', () {
      expect(
        p('https://www.instagram.com/zed/p/ZZFAKE_c1/'),
        const ParsedLink(kind: LinkKind.post, shortcode: 'ZZFAKE_c1'),
      );
    });

    test('extra segments are not supported', () {
      expect(p('https://www.instagram.com/p/ZZFAKE_c1/extra/'), isNull);
      expect(p('https://www.instagram.com/p/'), isNull);
    });
  });

  group('highlights', () {
    test('/stories/highlights/<id>/ with and without story_media_id', () {
      expect(
        p('https://www.instagram.com/stories/highlights/1700001/'),
        const ParsedLink(kind: LinkKind.highlight, highlightId: '1700001'),
      );
      expect(
        p(
          'https://www.instagram.com/stories/highlights/1700001/'
          '?story_media_id=3001_42&igsh=x',
        ),
        const ParsedLink(
          kind: LinkKind.highlight,
          highlightId: '1700001',
          mediaPk: '3001',
        ),
      );
    });

    test('a bad story_media_id is ignored', () {
      expect(
        p(
          'https://www.instagram.com/stories/highlights/1700001/?story_media_id=x_y',
        )?.mediaPk,
        isNull,
      );
    });

    test('the share short link /s/<base64> decodes to a highlight', () {
      final code = _short('highlight:1700001');
      expect(
        p('https://www.instagram.com/s/$code'),
        const ParsedLink(kind: LinkKind.highlight, highlightId: '1700001'),
      );
      expect(
        p('https://www.instagram.com/s/$code?story_media_id=3001_42&igsh=z'),
        const ParsedLink(
          kind: LinkKind.highlight,
          highlightId: '1700001',
          mediaPk: '3001',
        ),
      );
      // Padded and percent-encoded padding are accepted too.
      expect(
        p(
          'https://www.instagram.com/s/'
          '${base64Url.encode(utf8.encode('highlight:1700001'))}',
        )?.highlightId,
        '1700001',
      );
      final padded = base64Url.encode(utf8.encode('highlight:5'));
      expect(
        p(
          'https://www.instagram.com/s/${Uri.encodeComponent(padded)}',
        )?.highlightId,
        '5',
      );
    });

    test('a short link that is not a highlight, or is garbage', () {
      expect(p('https://www.instagram.com/s/${_short('story:1')}'), isNull);
      expect(
        p('https://www.instagram.com/s/${_short('highlight:ab')}'),
        isNull,
      );
      expect(p('https://www.instagram.com/s/!!!notbase64'), isNull);
      expect(p('https://www.instagram.com/s/'), isNull);
    });
  });

  group('text around the link and garbage', () {
    test('a link inside shared text, with trailing punctuation', () {
      expect(
        p('Look at this https://www.instagram.com/p/ZZFAKE_c1/?igsh=x, wow'),
        const ParsedLink(kind: LinkKind.post, shortcode: 'ZZFAKE_c1'),
      );
      expect(
        p('see (https://www.instagram.com/reel/ZZFAKE_c1/).')?.shortcode,
        'ZZFAKE_c1',
      );
    });

    test('unsupported or foreign links and garbage are null', () {
      for (final u in [
        '',
        '   ',
        'hello',
        'https://example.com/p/ZZFAKE_c1/',
        'https://notinstagram.com/p/ZZFAKE_c1/',
        'https://evil-instagram.com/p/ZZFAKE_c1/',
        'https://example.com/?u=instagram.com/p/ZZFAKE_c1/',
        'https://www.instagram.com/',
        'https://www.instagram.com/zed/',
        'https://www.instagram.com/explore/tags/cats/',
        'https://www.instagram.com/stories/highlights/abc/',
        'https://www.instagram.com/stories/highlights/',
        'javascript:alert(1)',
        'https://www.instagram.com/p/a/',
      ]) {
        expect(p(u), isNull, reason: u);
      }
    });

    test('containsInstagramLink is a cheap pre-check', () {
      expect(
        LinkParser.containsInstagramLink('x instagram.com/p/abcde/'),
        true,
      );
      expect(LinkParser.containsInstagramLink('nothing here'), false);
    });

    test('toString never shows the values', () {
      final s = p('https://www.instagram.com/stories/zed/3001/').toString();
      expect(s, 'ParsedLink(story)');
    });
  });
}
