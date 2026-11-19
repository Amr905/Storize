// Test-only: dense adversarial inputs.
// ignore_for_file: lines_longer_than_80_chars
// T-011 round 2: encodings, key spellings, log forging, ReDoS.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/log.dart';
import 'package:storize_domain/src/ports/diagnostic_log.dart';
import 'package:storize_domain/testing.dart';

const _s = 'ZZR2SECRETVALUE9f8e7d';

void _gone(String input) {
  final out = Redactor.redact(input);
  expect(out, isNot(contains(_s)), reason: 'leaked in: $input\n out: $out');
}

void main() {
  _n1n2();
  group('F1 percent-decoding', () {
    test('fully encoded CDN URL loses its signed params', () {
      final out = Redactor.redact(
        'https%3A%2F%2Fscontent.cdninstagram.com%2Fa.jpg%3Foh%3D$_s%26oe%3D$_s',
      );
      expect(out, isNot(contains(_s)));
      expect(out, contains('scontent.cdninstagram.com/a.jpg'));
    });
    test('double and triple encoding', () {
      _gone(
        'https%253A%252F%252Fscontent.cdninstagram.com%252Fa.jpg%253Foh%253D$_s',
      );
      _gone('sessionid%253D$_s');
      _gone('sessionid%25253D$_s');
    });
    test('invalid percent sequences never throw', () {
      for (final t in [
        '%',
        '%z',
        '%zz',
        '%4',
        '100%',
        '%%%%',
        '%C3%28',
        '%FF%FE',
        '%00',
        '%0A',
      ]) {
        expect(() => Redactor.redact('a $t b sessionid=$_s'), returnsNormally);
        _gone('a $t b sessionid=$_s');
      }
    });
    test('decoding never produces control characters', () {
      final out = Redactor.redact('x%0Ay sessionid%3D$_s');
      expect(out, isNot(contains('\n')));
    });
    test('harmless encoded text is left as written', () {
      const text = 'name%20with%20spaces and 100%25 done';
      expect(Redactor.redact(text), text);
    });
    test('idempotent on encoded input', () {
      const raw = 'sessionid%253D$_s';
      final once = Redactor.redact(raw);
      expect(Redactor.redact(once), once);
    });
  });

  group('F5-F7 encodings and spellings', () {
    test('spaces around the separator', () {
      _gone('sessionid = $_s');
      _gone('sessionid   :   $_s');
    });
    test('html entities', () {
      _gone('sessionid&#61;$_s');
      _gone('sessionid&#x3D;$_s');
      _gone('sessionid&#x3d;$_s');
    });
    test('unicode escapes in key and separator', () {
      _gone('{"sessionid":"$_s"}');
      _gone('sessionid=$_s');
    });
    test('doubly and triply escaped JSON', () {
      _gone(r'{\\"sessionid\\":\\"' + _s + r'\\"}');
      _gone(r'{\\\"sessionid\\\":\\\"' + _s + r'\\\"}');
    });
    test('zero-width and fullwidth characters', () {
      _gone('session​id=$_s');
      _gone('﻿sessionid‍=$_s');
      _gone('ｓｅｓｓｉｏｎｉｄ＝$_s');
      _gone('ｓｅｓｓｉｏｎｉｄ=$_s');
    });
    test('key spellings', () {
      for (final k in [
        'pin-hash',
        'pin_code',
        'pincode',
        'pinCode',
        'userPin',
        'user_pin',
        'session_id',
        'session-id',
        'sessionId',
        'SESSION_ID',
        'csrf-token',
        'ds-user-id',
        'access-token',
        'fb-dtsg',
        'pass_code',
        'PIN_HASH',
      ]) {
        _gone('$k=$_s');
        _gone('$k: $_s');
        _gone('{"$k":"$_s"}');
      }
    });
    test('v1: prefix in any case', () {
      _gone('V1:$_s');
      _gone('v1:$_s');
      _gone('V1:$_s:$_s');
    });
    test('key with no separator', () {
      _gone('sessionid $_s');
      _gone('session_id\t$_s');
      _gone('csrftoken $_s');
    });
    test('documented limits stay documented', () {
      // base64 of a cookie and a bare keyless token are not recognisable.
      expect(Redactor.redact('blob $_s'), contains(_s));
    });
  });

  group('no false positives', () {
    for (final t in [
      'the middle of the road',
      'a rural area',
      'pinned message',
      'pinning the version',
      'spinning wheel',
      'opinion=good',
      'page=2',
      'page=2&size=10',
      'midnight=0',
      'session timeout reached',
      'sessions: 3',
      'the session id is unknown',
      'tokenizer=fast',
      'user pinned 3 items',
      'v10 is out',
      'discount 100%25 off',
      'pincushion',
      'compin=3',
    ]) {
      test(t, () => expect(Redactor.redact(t), t));
    }
  });

  group('ReDoS', () {
    const n = 100 * 1024;
    final inputs = <String, String>{
      'backslashes after key': 'sessionid${r'\' * n}',
      'key + backslash quote repeated': r'sessionid\\"' * (n ~/ 12),
      'repeated key then spaces': 'sessionid ${' ' * 50}' * (n ~/ 60),
      'bare key repeated': 'sessionid abc ' * (n ~/ 14),
      'percent run': '%25' * (n ~/ 3),
      'percent invalid run': '%z' * (n ~/ 2),
      'entities': '&#6' * (n ~/ 3),
      'unicode escapes': r'\u00' * (n ~/ 4),
      'zero width': 'session${'​' * n}id=x',
      'fullwidth': 'ｓ' * n,
      'pin variants': 'user_pin-' * (n ~/ 9),
      'v1 upper': 'V1:' * (n ~/ 3),
    };
    for (final e in inputs.entries) {
      test(e.key, () {
        final sw = Stopwatch()..start();
        Redactor.redact(e.value);
        expect(sw.elapsedMilliseconds, lessThan(1000));
      });
    }
  });

  group('F2 log forging', () {
    late Directory tmp;
    late RotatingLogFile file;
    late FileDiagnosticLog log;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('storize_forge_');
      file = RotatingLogFile(Directory('${tmp.path}/l'));
      log = FileDiagnosticLog(
        file: file,
        clock: FakeClock(DateTime.utc(2026, 11, 19)),
      );
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    int entries() => file.current
        .readAsLinesSync()
        .where((l) => RegExp(r'^\d{4}-\d\d-\d\dT').hasMatch(l))
        .length;

    test('message, error and stack newlines cannot start an entry', () {
      const forged = '2026-11-19T00:00:00.000Z ERROR [crash] forged';
      for (final sep in ['\n', '\r\n', '\r', ' ', '\u0085', '\u000B']) {
        log.log(
          LogLevel.info,
          'net',
          'ok$sep$forged',
          error: StateError('e$sep$forged'),
          stack: StackTrace.fromString('#0 a$sep$forged'),
        );
      }
      expect(entries(), 6);
      for (final line in file.current.readAsLinesSync()) {
        expect(
          line.startsWith('2026-') || line.startsWith('  '),
          isTrue,
          reason: line,
        );
      }
    });

    test('continuation lines are prefixed and stack stays readable', () {
      log.log(
        LogLevel.error,
        't',
        'a\nb',
        stack: StackTrace.fromString('#0 f (x.dart:1:1)\n#1 g (y.dart:2:2)'),
      );
      final text = file.current.readAsStringSync();
      expect(text, contains('a\n  | b'));
      expect(text, contains('stack: #0 f (x.dart:1:1)\n  | #1 g (y.dart:2:2)'));
    });

    test(
      'a secret split across the injected newline text is still redacted',
      () {
        log.log(LogLevel.info, 't', 'x\nsessionid=$_s');
        expect(file.current.readAsStringSync(), isNot(contains(_s)));
      },
    );
  });

  group('F9 stray files on open', () {
    test('first append deletes storize.log.N with N >= maxFiles', () {
      final tmp = Directory.systemTemp.createTempSync('storize_stray_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File('${tmp.path}/storize.log.3').writeAsStringSync('x');
      File('${tmp.path}/storize.log.12').writeAsStringSync('x');
      File('${tmp.path}/storize.log.2').writeAsStringSync('keep');
      File('${tmp.path}/storize.log.bak').writeAsStringSync('keep');
      RotatingLogFile(tmp).append('hello');
      expect(File('${tmp.path}/storize.log.3').existsSync(), isFalse);
      expect(File('${tmp.path}/storize.log.12').existsSync(), isFalse);
      expect(File('${tmp.path}/storize.log.2').existsSync(), isTrue);
      expect(File('${tmp.path}/storize.log.bak').existsSync(), isTrue);
    });
  });
}

void _n1n2() {
  group('N1 scrub as written first', () {
    for (final sep in ['%3B', '%2C', '%26', '%22', '%20', '%27', '%7D']) {
      test('value split by $sep is redacted whole', () {
        final out = Redactor.redact('sessionid=ZZFAKE_HEAD${sep}ZZFAKE_TAIL');
        expect(out, isNot(contains('ZZFAKE_TAIL')));
        expect(out, isNot(contains('ZZFAKE_HEAD')));
      });
    }
    test('CDN URL with %20 in the query keeps no query', () {
      final out = Redactor.redact(
        'https://scontent.cdninstagram.com/a.jpg?ccb=1%20&xyz=ZZFAKE_Q',
      );
      expect(out, isNot(contains('ZZFAKE_Q')));
      expect(out, contains('?${Redactor.mask}'));
    });
    test('encoded CDN URL still gets its whole query stripped', () {
      final out = Redactor.redact(
        'https%3A%2F%2Fscontent.cdninstagram.com%2Fa.jpg%3Fccb%3D1%2520%26xyz%3DZZFAKE_Q',
      );
      expect(out, isNot(contains('ZZFAKE_Q')));
    });
  });

  group('N2 deep encodings', () {
    String enc(String v, int n) {
      var s = v;
      for (var i = 0; i < n; i++) {
        s = Uri.encodeComponent(s);
      }
      return s;
    }

    for (final n in [4, 5, 6, 7]) {
      test('key=value ${n}x encoded', () {
        _gone(enc('sessionid=$_s', n));
      });
      test('CDN URL ${n}x encoded', () {
        _gone(enc('https://scontent.cdninstagram.com/a.jpg?oh=$_s', n));
      });
    }
    test('harmless text stays as written', () {
      expect(Redactor.redact('a%2520b'), 'a%2520b');
    });
  });

  group('N4 tag separators', () {
    test('U+0085 and other separators in the tag become underscores', () {
      final tmp = Directory.systemTemp.createTempSync('storize_tag_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final file = RotatingLogFile(Directory('${tmp.path}/l'));
      FileDiagnosticLog(
        file: file,
        clock: FakeClock(DateTime.utc(2026, 11, 19)),
      ).log(LogLevel.info, 'a\u0085b c\u000Bd e', 'm');
      expect(file.current.readAsStringSync(), contains('[a_b_c_d_e]'));
    });
  });
}
