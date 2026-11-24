import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/redactor.dart';

/// Markers are obviously fake. Every test asserts none of them survives.
const _s1 = 'ZZFAKE_SECRET_ONE_a1b2c3';
const _s2 = 'ZZFAKE_SECRET_TWO_d4e5f6';

// ignore: use_raw_strings, a raw string cannot hold one backslash.
const _bs = '\\';

void _gone(String out, [List<String> secrets = const [_s1, _s2]]) {
  for (final s in secrets) {
    expect(out, isNot(contains(s)), reason: 'leaked $s in: $out');
  }
}

void main() {
  group('cookies', () {
    for (final name in const [
      'sessionid',
      'csrftoken',
      'ds_user_id',
      'rur',
      'mid',
    ]) {
      test('$name in key=value, key: value, JSON and encoded forms', () {
        for (final text in [
          '$name=$_s1',
          'got $name=$_s1; path=/',
          '$name: $_s1',
          '{"$name":"$_s1"}',
          '{"$name": "$_s1", "other": 1}',
          "{'$name': '$_s1'}",
          '{$_bs"$name$_bs":$_bs"$_s1$_bs"}',
          '$name%3D$_s1',
          '{${name.toUpperCase()}: $_s1}',
        ]) {
          final out = Redactor.redact(text);
          _gone(out);
          expect(out, contains(Redactor.mask), reason: text);
        }
      });
    }

    test('Cookie and Set-Cookie headers lose the whole value', () {
      final out = Redactor.redact(
        'Cookie: a=$_s1; b=$_s2; other=x\n'
        'Set-Cookie: foo=$_s2; Path=/; HttpOnly\n'
        'next line stays',
      );
      _gone(out);
      expect(out, contains('Cookie: ${Redactor.mask}'));
      expect(out, contains('next line stays'));
      expect(out, isNot(contains('HttpOnly')));
    });

    test('cookie string with spaces inside a quoted JSON value', () {
      final out = Redactor.redact('{"cookie": "a=$_s1; b=$_s2", "ok": true}');
      _gone(out);
      expect(out, contains('"ok": true'));
    });

    test('unrelated words that contain a cookie name are kept', () {
      const text = 'middle=1 amid=2 rural=3 mid-flight';
      expect(Redactor.redact(text), text);
    });
  });

  group('tokens', () {
    test('Bearer and Authorization', () {
      final out = Redactor.redact(
        'Authorization: Bearer $_s1\nretry with Bearer $_s2 now',
      );
      _gone(out);
      expect(out, contains('Bearer ${Redactor.mask}'));
    });

    test('x-ig-* and x-csrftoken headers', () {
      final out = Redactor.redact(
        'x-ig-www-claim: $_s1\nX-IG-App-ID: $_s2\nx-csrftoken: $_s1',
      );
      _gone(out);
      expect(out, isNot(contains('hmac')));
    });

    test('x-ig-* keys inside JSON', () {
      _gone(Redactor.redact('{"x-ig-www-claim":"$_s1","x-ig-app-id":"$_s2"}'));
    });

    for (final name in const [
      'fb_dtsg',
      'lsd',
      'csrf',
      'csrf_token',
      'jazoest',
      'access_token',
      'token',
    ]) {
      test('$name in form body, JSON and URL-encoded', () {
        _gone(Redactor.redact('a=1&$name=$_s1&b=2'));
        _gone(Redactor.redact('{"$name":"$_s1"}'));
        _gone(Redactor.redact('a=1&$name%3D$_s1'));
      });
    }

    test('values stop at separators so neighbours survive', () {
      final out = Redactor.redact('a=1&lsd=$_s1&b=2');
      expect(out, 'a=1&lsd=${Redactor.mask}&b=2');
    });
  });

  group('signed URL params', () {
    test('CDN URLs lose the whole query', () {
      const base = 'https://scontent-xyz1-1.cdninstagram.com/v/t51/1_n.jpg';
      const query =
          '?stp=dst&_nc_ht=scontent.cdninstagram.com&_nc_cat=1&efg=$_s1'
          '&oh=$_s2&oe=65ABCDEF&sig=$_s1';
      final out = Redactor.redact('GET $base$query done');
      _gone(out);
      expect(out, 'GET $base?${Redactor.mask} done');
    });

    test('other CDN hosts and fragments', () {
      for (final host in ['video.fbcdn.net', 'a.cdninstagram.com:443']) {
        final out = Redactor.redact('https://$host/p/v.mp4?x=$_s1#frag$_s2');
        _gone(out);
        expect(out, startsWith('https://$host/p/v.mp4?'));
      }
    });

    test('JSON-escaped CDN URL', () {
      const url = 'https:$_bs/$_bs/scontent.cdninstagram.com$_bs/v$_bs/1.jpg';
      final out = Redactor.redact('{"url":"$url?oh=$_s1${_bs}u0026oe=$_s2"}');
      _gone(out);
      expect(out, contains('1.jpg?${Redactor.mask}'));
    });

    test('CDN URL without a query is unchanged', () {
      const url = 'https://scontent.cdninstagram.com/v/t51/1_n.jpg';
      expect(Redactor.redact(url), url);
    });

    test('a host that only mentions a CDN name is not treated as one', () {
      final out = Redactor.redact('https://example.com/?next=fbcdn.net&a=1');
      expect(out, contains('a=1'));
    });

    for (final p in const ['oh', 'oe', 'efg', 'sig', '_nc_ht', '_nc_ohc']) {
      test('$p is removed from non-CDN URLs and bare query strings', () {
        _gone(Redactor.redact('https://example.com/x?a=1&$p=$_s1&b=2'));
        _gone(Redactor.redact('?$p=$_s1'));
        _gone(Redactor.redact('a=1&$p%3D$_s1'));
      });
    }

    test('non-signature params of other URLs survive', () {
      const url = 'https://example.com/x?page=2&sort=asc';
      expect(Redactor.redact(url), url);
    });
  });

  group('PIN', () {
    test('v1 hash and cooldown strings', () {
      final out = Redactor.redact(
        'stored v1:120000:c2FsdFNBTFQ=:aGFzaEhBU0g9 and '
        '{"pin_hash":"v1:1:2:3"} cooldown v1:3:1700000000000',
      );
      expect(out, isNot(contains('c2FsdFNBTFQ')));
      expect(out, isNot(contains('aGFzaEhBU0g9')));
      expect(out, isNot(contains('1700000000000')));
      expect(out, contains('v1:${Redactor.mask}'));
    });

    for (final key in const ['pin', 'pin_hash', 'pinHash', 'new_pin']) {
      test('$key values are removed', () {
        for (final text in ['$key=482915', '$key: 482915', '{"$key":482915}']) {
          final out = Redactor.redact(text);
          expect(out, isNot(contains('482915')), reason: text);
        }
      });
    }

    test('words that merely start with pin are kept', () {
      const text = 'pinned: true, pinging=1';
      expect(Redactor.redact(text), text);
    });
  });

  group('behaviour', () {
    test('plain text is unchanged', () {
      const text = 'run start scope=stories mode=direct waited=1200ms';
      expect(Redactor.redact(text), text);
    });

    test('is idempotent', () {
      final once = Redactor.redact(
        'sessionid=$_s1 Cookie: x=$_s2 '
        'https://a.cdninstagram.com/1.jpg?oh=$_s1 v1:1:2:3 Bearer $_s2',
      );
      expect(Redactor.redact(once), once);
    });

    test('long text is cut', () {
      final out = Redactor.redact('a' * 10000);
      expect(out.length, lessThan(Redactor.maxLength + 40));
      expect(out, contains('[cut 6000]'));
    });

    test('redactFirstLine keeps one redacted, short line', () {
      final out = Redactor.redactFirstLine(
        'boom sessionid=$_s1\nsecond line $_s2',
      );
      _gone(out);
      expect(out, isNot(contains('second')));
      expect(Redactor.redactFirstLine('x' * 500).length, 200);
    });

    test('bodySummary logs size only', () {
      expect(Redactor.bodySummary('{"a":"$_s1"}'), '[body 32 chars]');
      expect(Redactor.bodySummary(null), '[body 0 chars]');
    });
  });

  group('fuzz-style: secrets embedded in structures', () {
    test('nested JSON, URLs and multiline text', () {
      const text =
          '''
request failed
  headers: {Cookie: sessionid=$_s1; csrftoken=$_s2, x-ig-www-claim: $_s2}
  body: {"data":{"user":{"id":"1","session":{"sessionid":"$_s1",
        "csrftoken":"$_s2","ds_user_id":"$_s1","rur":"$_s2","mid":"$_s1"}},
        "url":"https:\\/\\/scontent.cdninstagram.com\\/v\\/1.jpg?oh=$_s1\\u0026oe=$_s2",
        "fb_dtsg":"$_s1","lsd":"$_s2"}}
  form: fb_dtsg=$_s1&lsd=$_s2&jazoest=2$_s1&pin=482915
  location: https://www.instagram.com/accounts/login/?next=/x/&token=$_s2
  media: https://video.fbcdn.net/o1/v/t2/f1/m1.mp4?_nc_cat=1&efg=$_s1&oh=$_s2
  Authorization: Bearer $_s1
  pin hash v1:100000:$_s1:$_s2
done''';
      final out = Redactor.redact(text);
      _gone(out);
      expect(out, isNot(contains('482915')));
      expect(out, contains('request failed'));
      expect(out, contains('done'));
    });

    test('many generated combinations never leak', () {
      const keys = ['sessionid', 'csrftoken', 'fb_dtsg', 'lsd', 'rur', 'mid'];
      const wrappers = <String Function(String, String)>[
        _plain,
        _json,
        _query,
        _header,
        _dartMap,
        _multiline,
      ];
      for (final k in keys) {
        for (final w in wrappers) {
          final out = Redactor.redact(w(k, _s1));
          _gone(out);
        }
      }
    });
  });
}

String _plain(String k, String v) => 'x $k=$v y';
String _json(String k, String v) => '{"a":{"$k":"$v"},"b":[1,2]}';
String _query(String k, String v) => 'https://example.com/p?z=1&$k=$v&q=2';
String _header(String k, String v) => 'Cookie: $k=$v\nHost: example.com';
String _dartMap(String k, String v) => '{a: 1, $k: $v, b: 2}';
String _multiline(String k, String v) => 'line1\n  $k: $v\nline3';
