import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';

import 'plugin_rules.dart';

void main() {
  final at = DateTime.utc(2026, 3, 7, 4, 5, 9);

  String name({
    String username = 'nour_k',
    DateTime? postedAt,
    String remoteId = '3141592653',
    int? slide,
    String ext = 'jpg',
  }) => displayNameFor(
    username: username,
    postedAt: postedAt ?? at,
    remoteId: remoteId,
    slideIndex: slide,
    ext: ext,
  );

  group('displayNameFor pattern', () {
    test('story without slide', () {
      expect(name(), 'nour_k_20260307_040509_3141592653.jpg');
    });

    test('post with slide index, including 0', () {
      expect(name(slide: 0), 'nour_k_20260307_040509_3141592653_0.jpg');
      expect(name(slide: 12), 'nour_k_20260307_040509_3141592653_12.jpg');
    });

    test('uses UTC for a local-time input', () {
      final plus3 = DateTime.parse('2026-03-07T02:05:09+03:00');
      expect(name(postedAt: plus3), contains('_20260306_230509_'));
    });

    test('extension is lower-cased and loses dots', () {
      expect(name(ext: '.MP4'), endsWith('.mp4'));
    });

    test('rejects a negative slide and an empty extension', () {
      expect(() => name(slide: -1), throwsArgumentError);
      expect(() => name(ext: '../'), throwsArgumentError);
      expect(() => name(ext: ''), throwsArgumentError);
    });
  });

  group('sanitising', () {
    final hostile = <String>[
      '',
      ' ',
      '.',
      '..',
      '...',
      '.hidden',
      'a/b',
      '../../etc/passwd',
      r'a\b',
      'a:b*c?d"e<f>g|h',
      'tab\there',
      'new\nline',
      'nul\u0000x',
      'del\u007Fx',
      'c1\u0085x',
      'bidi\u202Eevil',
      'iso\u2066x\u2069',
      'zw\u200Bx\u200Fy',
      'bom\uFEFFx',
      'ls\u2028ps\u2029',
      'soft\u00ADhyphen',
      'trailing.',
      'trailing ',
      'a..b',
      '~',
      'C:',
      'emoji\u{1F600}name',
      'عربي',
      'x' * 400,
      '\u{1F600}' * 200,
    ];

    test('every hostile username gives a name the plugin accepts', () {
      for (final u in hostile) {
        final n = name(username: u);
        expect(pluginRejectsDisplayName(n), isNull, reason: 'username "$u"');
        expect(n.length, lessThanOrEqualTo(255));
      }
    });

    test('every hostile remote id gives a name the plugin accepts', () {
      for (final id in hostile) {
        expect(
          pluginRejectsDisplayName(name(remoteId: id, slide: 3)),
          isNull,
          reason: 'id "$id"',
        );
      }
    });

    test('every hostile username gives a folder the plugin accepts', () {
      for (final u in hostile) {
        final dir = relativeDirFor(u);
        expect(pluginRejectsRelativeDir(dir), isNull, reason: 'username "$u"');
        expect(dir.contains('/'), isFalse, reason: 'single segment');
        expect(dir.length, lessThanOrEqualTo(100));
      }
    });

    test('the mirror really rejects the raw hostile values', () {
      // Guards the helper: if it accepted everything the tests above prove
      // nothing.
      for (final bad in [
        'a/b',
        '.x',
        'x.',
        'a..b',
        'a:b',
        'bidi\u202Ex',
        'zw\u200Bx',
        'x\u0000',
        '',
      ]) {
        expect(pluginRejectsDisplayName(bad), isNotNull, reason: bad);
      }
      expect(pluginRejectsRelativeDir('a//b'), isNotNull);
      expect(pluginRejectsRelativeDir('/abs'), isNotNull);
    });

    test('empty username falls back to an ASCII name', () {
      expect(name(username: ''), startsWith('user_2026'));
      expect(name(username: '..'), startsWith('_'));
      expect(relativeDirFor(''), 'unknown');
    });

    test('bad characters become underscores', () {
      expect(relativeDirFor('a/b:c'), 'a_b_c');
      expect(relativeDirFor('.hidden'), '_hidden');
      expect(relativeDirFor('nour_k'), 'nour_k');
      expect(relativeDirFor('x.y'), 'x.y');
    });

    test('long names are cut without splitting a surrogate pair', () {
      final n = name(username: '\u{1F600}' * 100);
      // The cut must leave valid UTF-16.
      expect(() => Uri.encodeFull(n), returnsNormally);
      expect(n.length, lessThanOrEqualTo(255));
    });

    test('a username with a different case is kept as is', () {
      expect(name(username: 'Nour.K'), startsWith('Nour.K_'));
    });
  });
}
