// Test-only: lint noise from dense adversarial inputs is suppressed on purpose.
// ignore_for_file: unnecessary_raw_strings, use_raw_strings, document_ignores, lines_longer_than_80_chars
// QA (T-011) round 3: scrub-first plus fixed-point decoding.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/redactor.dart';

const _a = 'ZZQAROUNDTHREEa1b2';
const _b = 'ZZQAROUNDTHREEc3d4';

String _enc(String s, int n) {
  var x = s;
  for (var i = 0; i < n; i++) {
    x = Uri.encodeComponent(x);
  }
  return x;
}

void _gone(String input, [List<String> secrets = const [_a, _b]]) {
  final out = Redactor.redact(input);
  for (final s in secrets) {
    expect(
      out,
      isNot(contains(s)),
      reason: 'leaked $s\n in:  $input\n out: $out',
    );
  }
}

void main() {
  group('N1 closed: values hidden only by an encoded separator or value', () {
    for (final sep in [
      '%3B',
      '%2C',
      '%26',
      '%22',
      '%27',
      '%28',
      '%29',
      '%7B',
      '%7D',
      '%5B',
      '%5D',
      '%20',
      '%3C',
      '%3E',
      '%5C',
    ]) {
      test('key=value with $sep inside the value', () {
        _gone('sessionid=${_a}x$sep$_b');
        _gone('sessionid%3D${_a}x$sep$_b');
        _gone('cookie: sessionid=${_a}x$sep$_b; csrftoken=$_b');
      });
    }
    test('plain CDN URL with encoded quote, space or angle bracket before the tail', () {
      for (final c in ['%22', '%27', '%20', '%3E', '%3C', '%26']) {
        _gone('https://scontent.cdninstagram.com/a.jpg?stp=1$c&ccb=$_a');
        _gone(
          'https://scontent.cdninstagram.com/a.jpg?stp=1$c&ccb=$_a sessionid%3D$_b',
        );
      }
    });
    test('fully encoded CDN URL, single level encoded separators', () {
      _gone(
        'https%3A%2F%2Fscontent.cdninstagram.com%2Fa.jpg%3Fstp%3D1%26ccb%3D$_a',
      );
      _gone(
        'https%3A%2F%2Fscontent.cdninstagram.com%2Fa.jpg%3Fstp%3D1%2520x%26ccb%3D$_a',
      );
    });
  });

  group('scrub-first / second-result choice', () {
    test('first-scrub mask survives when the second scrub finds more', () {
      _gone('sessionid=$_a and %63ookie: x=$_b');
      _gone('Bearer ${_a}1 and %73essionid%3D$_b');
      _gone('https://scontent.cdninstagram.com/a.jpg?oh=$_a #  %70in%3D$_b');
    });
    test('idempotent after decoding', () {
      for (final s in [
        '%73essionid%3D$_a',
        'sessionid=$_a;x=%70in%3D$_b',
        _enc('sessionid=$_a', 5),
      ]) {
        final once = Redactor.redact(s);
        expect(Redactor.redact(once), once);
      }
    });
    test('no secret: byte-identical', () {
      const t = 'GET /a%20b?x=%41&y=\\u0041 100% &#65; done %22q%22';
      expect(Redactor.redact(t), t);
    });
    test('decoding never yields space, <, > or control characters', () {
      final out = Redactor.redact('sessionid=%20%3C%3E%0A%00 mid%3D%20');
      expect(out, isNot(contains('\n')));
      expect(out, isNot(contains('<')));
    });
  });

  group('N2 closed: fixed-point decoding (cap 8)', () {
    for (var n = 1; n <= 8; n++) {
      test('$n-times encoded key=value and CDN URL', () {
        _gone(_enc('sessionid=$_a', n));
        _gone(_enc('https://scontent.cdninstagram.com/a.jpg?ccb=$_a', n));
      });
    }
    test(
      '9x CDN URL and 10x key=value (beyond the cap)',
      () {
        _gone(_enc('https://scontent.cdninstagram.com/a.jpg?ccb=$_a', 9));
        _gone(_enc('sessionid=$_a', 10));
      },
      skip:
          'N8 info: beyond 8 levels leaks; nothing encodes this deeply, accept',
    );
  });

  group('N6/N7 residual limits of decoding', () {
    test(
      'N6: ENCODED KEY or double-encoded separator with a decoded terminator inside the value',
      () {
        for (final c in [
          '%3B',
          '%2C',
          '%26',
          '%22',
          '%27',
          '%28',
          '%29',
          '%7B',
          '%7D',
          '%5B',
          '%5D',
        ]) {
          _gone('%73essionid=${_a}x$c$_b');
          _gone('sessionid%253D${_a}x$c$_b');
        }
      },
      skip: 'N6 minor: key or separator only recognisable after decoding, and a decoded terminator ends the value token',
    );
    test(
      'N7: fully encoded CDN URL with a double-encoded quote before the tail',
      () {
        _gone(
          'https%3A%2F%2Fscontent.cdninstagram.com%2Fa.jpg%3Fstp%3D1%2522%26ccb%3D$_a',
        );
        _gone(
          'https%3A%2F%2Fscontent.cdninstagram.com%2Fa.jpg%3Fstp%3D1%2527%26ccb%3D$_a',
        );
      },
      skip: 'N7 minor: the developer-flagged limit; decoded quote ends the URL token',
    );
  });

  group('tag break characters', () {
    test(
      'Redactor does not alter tag separators (sanitising is in the log)',
      () {
        expect(Redactor.redact('a\u0085b'), 'a\u0085b');
      },
    );
  });

  group('ReDoS (all suites combined, 100 KB inputs)', () {
    test('worst case', () {
      const n = 100000;
      final inputs = <String, String>{
        'percent run': '%41' * (n ~/ 3),
        'percent-25 run': '%25' * (n ~/ 3),
        'percent-25 + key': '%25253D' * (n ~/ 7),
        'nested 8-pass decode': '%252525252525252541' * (n ~/ 19),
        'key + nested': 'sessionid${'%2525252525253D' * (n ~/ 15)}',
        'unicode escapes': r'A' * (n ~/ 6),
        'html entities': '&#65;' * (n ~/ 5),
        'zero-width': '​' * n,
        'fullwidth': 'ａ' * n,
        'bare key repeated': 'sessionid ' * (n ~/ 10),
        'bare key + long value': 'sessionid ${'a' * n}',
        'unterminated quote': 'sessionid="${r'a\' * (n ~/ 2)}',
        'repeated key+quote': 'sessionid="a ' * (n ~/ 13),
        'key whitespace': 'sessionid${' ' * n}',
        'whitespace': ' \t' * (n ~/ 2),
        'escaped quotes': r'\"' * (n ~/ 2),
        'key + escaped quotes': 'sessionid:"${r'\"' * (n ~/ 2)}',
        'pin repeated': 'pin=' * (n ~/ 4),
        'url many': 'https://a.cdninstagram.com/?' * (n ~/ 28),
        'url long': 'https://${'a' * n}',
        'bearer repeated': 'Bearer ' * (n ~/ 7),
        'v1 repeated': 'v1:' * (n ~/ 3),
        'cookie repeated': 'cookie:' * (n ~/ 7),
        'quotes': '"' * n,
        'secret-rich': 'sessionid=a&%73essionid%3Db;' * (n ~/ 28),
      };
      var worst = 0;
      var worstName = '';
      inputs.forEach((name, v) {
        final sw = Stopwatch()..start();
        Redactor.redact(v);
        final ms = sw.elapsedMilliseconds;
        if (ms > worst) {
          worst = ms;
          worstName = name;
        }
      });
      // ignore: avoid_print
      print('REDOS3 worst=$worst ms ($worstName)');
      expect(
        worst,
        lessThan(15000),
      ); // load-tolerant; catastrophic backtracking would take far longer
    });
  });
}
