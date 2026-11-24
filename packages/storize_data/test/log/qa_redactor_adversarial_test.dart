// Test-only: lint noise from dense adversarial inputs is suppressed on purpose.
// ignore_for_file: cascade_invocations, lines_longer_than_80_chars, prefer_interpolation_to_compose_strings, unnecessary_raw_strings, use_raw_strings
// QA (T-011): adversarial redaction tests. The former known-gap tests (GAP)
// were un-skipped in round 2 once the leaks were closed.
// See docs/05-reviews/T-011.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/redactor.dart';

const _s1 = 'ZZQASECRETONE9f8e7d';
const _s2 = 'ZZQASECRETTWO1a2b3c';

void _gone(String input, [List<String> secrets = const [_s1, _s2]]) {
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
  group('cookies: whitespace and joining', () {
    for (final input in [
      'sessionid=$_s1;csrftoken=$_s2;mid=x',
      'sessionid =\t$_s1',
      'c:  sessionid\t=\t$_s1 ; csrftoken = $_s2',
      'COOKIE: sessionid=$_s1',
      'SESSIONID=$_s1',
      'cookie:sessionid=$_s1; csrftoken=$_s2',
      'cookie\t:\tsessionid=$_s1; csrftoken=$_s2',
      'cookie : sessionid=$_s1',
      ':authority: x\ncookie: a=$_s1; b=$_s2\nfoo: bar',
      'cookie: sessionid=$_s1\r\ncookie: csrftoken=$_s2',
      'headers: {Cookie: [sessionid=$_s1; csrftoken=$_s2]}',
      '{set-cookie: [sessionid=$_s1; Max-Age=1]}',
      'Set-Cookie: sessionid=$_s1; Path=/; HttpOnly',
      'curl -H "Cookie: sessionid=$_s1" https://x',
      "curl -H 'Cookie: sessionid=$_s1; csrftoken=$_s2' https://x",
      'curl --cookie "sessionid=$_s1" https://x',
      'a=b&sessionid=$_s1&c=d',
      'sessionid="Z Z $_s1"',
      "sessionid='Z Z $_s1'",
      'sessionid:\n$_s1',
      'rur="$_s1,2,3:01abc"',
      'ds_user_id=$_s1',
      'IG-U-DS-USER-ID: $_s1',
      'x-ig-www-claim: $_s1',
      'X-IG-App-ID: $_s1',
      'x-csrftoken: $_s1',
      'Authorization:Bearer $_s1',
      'authorization: Basic $_s1',
      'Bearer\t$_s1',
      'curl -H "Authorization: Bearer $_s1"',
    ]) {
      test(
        input.replaceAll('\n', r'\n').replaceAll('\r', r'\r'),
        () => _gone(input),
      );
    }
  });

  group('encodings', () {
    test('single URL-encoded key=value', () {
      _gone('q=sessionid%3D$_s1%3Bcsrftoken%3D$_s2');
      _gone('sessionid%3d$_s1');
    });
    test('JSON: escaped quotes and escaped solidus', () {
      _gone(r'{\"sessionid\":\"' + _s1 + r'\"}');
      _gone(r'{"sessionid":"' + _s1 + r'","x":"y"}');
      _gone(r'{"sessionid":"ZZ\"' + _s1 + '"}');
    });
    test('unicode-escaped VALUE does not matter, key still matches', () {
      _gone(r'{"sessionid":"\u005a' + _s1 + '"}');
    });
    test(
      'GAP (minor): double-encoded separator sessionid%253D',
      () => _gone('x sessionid%253D$_s1'),
    );
    test(
      'GAP (minor): unicode-escaped key {"\\u0073essionid":...}',
      () => _gone(r'{"\u0073essionid":"' + _s1 + '"}'),
    );
    test(
      'GAP (minor): \\u003d as separator',
      () => _gone(r'sessionid\u003d' + _s1),
    );
    test(
      'GAP (minor): HTML entity separator',
      () => _gone('sessionid&#61;$_s1'),
    );
    test(
      'GAP (minor): doubly escaped JSON {\\\\"sessionid\\\\":...}',
      () => _gone(r'{\\"sessionid\\":\\"' + _s1 + r'\\"}'),
    );
    test('GAP (minor): zero-width char inside key / fullwidth key', () {
      _gone('sessionid\u200b=$_s1');
      _gone('ｓｅｓｓｉｏｎｉｄ=$_s1');
    });
    test('DOCUMENTED LIMIT: base64 of a cookie cannot be recognised', () {
      // base64('sessionid=ZZQASECRETONE9f8e7d')
      const b64 = 'c2Vzc2lvbmlkPVpaUUFTRUNSRVRPTkU5ZjhlN2Q=';
      expect(Redactor.redact('blob $b64'), contains(b64));
    });
  });

  group('CDN URLs', () {
    for (final host in [
      'SCONTENT-CAI1-1.CDNINSTAGRAM.COM',
      'scontent-cai1-1.cdninstagram.com:443',
      'scontent.cdninstagram.com',
      'instagram.fcai1-1.fna.fbcdn.net',
      'video.fcai1-1.fna.fbcdn.net',
      'scontent.fbcdn.net:8443',
      'user:pw@scontent.cdninstagram.com',
    ]) {
      test('query stripped for $host', () {
        _gone('see https://$host/v/t.jpg?stp=$_s2&oh=$_s1&oe=$_s2 now');
        _gone('HTTPS://$host/v/t.mp4?efg=$_s1&_nc_ht=$_s2');
        _gone('http://$host/v/x?unknownparam=$_s1');
      });
    }
    test('JSON-escaped URL', () {
      _gone(
        r'{"url":"https:\/\/scontent.cdninstagram.com\/a.jpg?stp=' +
            _s1 +
            r'&oh=' +
            _s2 +
            r'"}',
      );
    });
    test('fragment before and after query', () {
      _gone('https://scontent.cdninstagram.com/p.jpg?oh=$_s1#frag');
      _gone('https://scontent.cdninstagram.com/p.jpg#frag?oh=$_s1&oe=$_s2');
      _gone('https://scontent.cdninstagram.com/p.jpg#oh=$_s1');
    });
    test('signed params on a NON-CDN host are still removed', () {
      _gone('https://other.example/x.jpg?oh=$_s1&oe=$_s2');
      _gone('https://other.example/x.jpg?_nc_sid=$_s1&sig=$_s2');
    });
    test('srcset list with several signed URLs', () {
      _gone(
        'srcset="https://scontent.cdninstagram.com/a.jpg?oh=$_s1 320w, '
        'https://scontent.cdninstagram.com/b.jpg?oh=$_s2 640w"',
      );
      _gone(
        'srcset=https://scontent.cdninstagram.com/a.jpg?oh=$_s1 320w, '
        'https://scontent.cdninstagram.com/b.jpg?stp=$_s2 640w',
      );
    });
    test('look-alike host: suffix attack still hits signed params', () {
      _gone('https://scontent.cdninstagram.com.evil.io/x?oh=$_s1');
      _gone('https://evilcdninstagram.com.attacker.io/x?token=$_s1');
    });
    test('stack trace and Dio-style error text containing URLs', () {
      _gone('#0 foo (https://scontent.cdninstagram.com/a.jpg?stp=$_s1:1:2)');
      _gone(
        'DioException [bad response]: GET https://scontent.cdninstagram.com/a.jpg?stp=$_s1&oe=$_s2 '
        'headers {cookie: [sessionid=$_s2]}',
      );
    });
    test(
      'GAP (minor/major): fully percent-encoded CDN URL',
      () => _gone(
        'https%3A%2F%2Fscontent.cdninstagram.com%2Fa.jpg%3Foh%3D$_s1%26oe%3D$_s2',
      ),
    );
  });

  group('error text', () {
    test('Error.toString with embedded cookie and newline', () {
      _gone('StateError: Bad state: cookie: sessionid=$_s1; csrftoken=$_s2');
      _gone(StateError('x\nCookie: a=$_s1').toString());
    });
  });

  group('truncation', () {
    test('secret straddling the 4000 boundary leaves no prefix', () {
      for (var pad = 3970; pad <= 4001; pad++) {
        final out = Redactor.redact('${'x' * pad} sessionid=${_s1}tail');
        // No fragment of the secret of 4+ chars may survive.
        expect(out, isNot(contains('ZZQA')), reason: 'pad=$pad');
        expect(out, isNot(contains(_s1.substring(0, 6))), reason: 'pad=$pad');
      }
    });
    test('signed CDN URL straddling the boundary', () {
      for (var pad = 3950; pad <= 4001; pad += 3) {
        final out = Redactor.redact(
          '${'x' * pad} https://scontent.cdninstagram.com/a.jpg?oh=$_s1',
        );
        expect(out, isNot(contains('ZZQA')), reason: 'pad=$pad');
      }
    });
    test('output length is bounded', () {
      final out = Redactor.redact('a' * 1000000);
      expect(out.length, lessThan(Redactor.maxLength + 40));
    });
    test('idempotent', () {
      const input =
          'cookie: sessionid=$_s1\nhttps://a.cdninstagram.com/x?oh=$_s2';
      final once = Redactor.redact(input);
      expect(Redactor.redact(once), once);
    });
  });

  group('ReDoS: 100 KB adversarial inputs finish fast', () {
    const n = 100000;
    final inputs = <String, String>{
      'unterminated quote': 'sessionid="${r'a\' * (n ~/ 2)}',
      'repeated key+quote': 'sessionid="a ' * (n ~/ 13),
      'key then whitespace': 'sessionid${' ' * n}',
      'key quote whitespace': 'sessionid"${' ' * n}x',
      'repeated key': 'sessionid ' * (n ~/ 10),
      'long url': 'https://${'a' * n}',
      'many cdn urls': 'https://a.cdninstagram.com/?' * (n ~/ 28),
      'bearer': 'Bearer ${'a' * n}!',
      'bearer repeated': 'Bearer ' * (n ~/ 7),
      'v1 repeated': 'v1:' * (n ~/ 3),
      'cookie repeated': 'cookie:' * (n ~/ 7),
      'whitespace': ' \t' * (n ~/ 2),
      'quotes': '"' * n,
      'escaped quotes': r'\"' * (n ~/ 2),
      'key + escaped quotes': 'sessionid:"${r'\"' * (n ~/ 2)}',
      'pin repeated': 'pin=' * (n ~/ 4),
    };
    inputs.forEach((name, value) {
      test(name, () {
        final sw = Stopwatch()..start();
        Redactor.redact(value);
        // Observed worst case ~150 ms; 2 s leaves headroom on slow CI.
        expect(sw.elapsedMilliseconds, lessThan(15000));
      });
    });
  });

  group('PIN and hashes', () {
    test('keyed PIN forms', () {
      for (final k in [
        'pin',
        'PIN',
        'pin_hash',
        'pinHash',
        'new_pin',
        'passcode',
      ]) {
        _gone('$k=$_s1');
        _gone('$k: $_s1');
        _gone('{"$k":"$_s1"}');
      }
      expect(Redactor.redact('pin=1234'), isNot(contains('1234')));
      expect(Redactor.redact('{"pin":1234}'), isNot(contains('1234')));
    });
    test('v1: hash', () => _gone('v1:$_s1:$_s2'));
    test('GAP (minor): V1: uppercase prefix and key spellings pin-hash, pin_code, userPin, pincode', () {
      _gone('V1:$_s1');
      _gone('pin-hash: $_s1');
      _gone('pin_code: $_s1');
      _gone('userPin=$_s1');
      _gone('pincode=$_s1');
    });
    test('GAP (minor): session_id / session-id / sessionId spellings', () {
      _gone('session_id=$_s1');
      _gone('session-id=$_s1');
    });
    test(
      'GAP (minor): bare `sessionid <value>` with no separator',
      () => _gone('sessionid $_s1'),
    );
  });
}
