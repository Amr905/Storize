import 'dart:convert';

import 'package:storize_domain/storize_domain.dart';
import 'package:test/test.dart';

void main() {
  group('QA T-060 hostile input', () {
    for (final s in [
      'javascript:alert(1)//instagram.com/p/abcdef',
      'https://instagram.com.evil.com/p/abcdef/',
      'https://instagram.com@evil.com/p/abcdef/',
      'https://user:pw@instagram.com/p/abcdef/',
      'https://evil.com/?u=instagram.com/p/abcdef',
      'https://evil.com/instagram.com/p/abcdef',
      'https://xn--nstagram-4ya.com/p/abcdef/',
      'https://іnstagram.com/p/abcdef/',
      'https://instagram.com/stories/a/12x34/',
      'https://instagram.com/stories/a/${'9' * 26}/',
      'https://instagram.com/p/ab/',
      'https://instagram.com/p/abc def/',
      'https://instagram.com/s/!!!notbase64',
      'https://instagram.com/s/${base64Url.encode(utf8.encode('user:123'))}',
      'https://instagram.com/s/${base64Url.encode(utf8.encode('highlight:12a'))}',
      'https://instagram.com/s/${base64Url.encode([0xff, 0xfe, 0xfd])}',
      'https://instagram.com/p/%00%0d%0a/',
      '',
      '\u{1F600}' * 100,
    ]) {
      test('refuses ${s.length > 40 ? s.substring(0, 40) : s}', () {
        expect(LinkParser.parse(s), isNull);
      });
    }
    test('huge input does not crash and is fast', () {
      final sw = Stopwatch()..start();
      expect(LinkParser.parse('a' * 2000000), isNull);
      expect(LinkParser.parse('instagram.com/' * 100000), isNull);
      expect(
        LinkParser.parse('${'x' * 1000000} instagram.com/p/abcdef'),
        isNotNull,
      );
      expect(sw.elapsed.inSeconds, lessThan(10));
    });
    test('fragment-prefixed fake host: shortcode is still sanitised', () {
      final p = LinkParser.parse('https://evil.com#instagram.com/p/abcdef');
      if (p != null) expect(p.shortcode, 'abcdef');
    });
    test('toString does not leak', () {
      expect(
        LinkParser.parse('instagram.com/stories/bob/123')!.toString(),
        isNot(contains('bob')),
      );
    });
  });
}
