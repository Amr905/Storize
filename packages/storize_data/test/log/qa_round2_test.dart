// Test-only: lint noise from dense adversarial inputs is suppressed on purpose.
// ignore_for_file: prefer_foreach, no_adjacent_strings_in_list, unnecessary_raw_strings, unnecessary_string_interpolations, use_raw_strings, unnecessary_brace_in_string_interps, document_ignores, lines_longer_than_80_chars
// QA (T-011) round 2: probes of the decode-then-redact design.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/file_diagnostic_log.dart';
import 'package:storize_data/log/redactor.dart';
import 'package:storize_data/log/rotating_log_file.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

const _a = 'ZZQAROUNDTWOa1b2';
const _b = 'ZZQAROUNDTWOc3d4';

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
  group('decode switch: mixed encoded and plain secrets on one line', () {
    test('plain + encoded key, both orders', () {
      _gone('sessionid=$_a; x=%73essionid%3D$_b');
      _gone('x=%73essionid%3D$_b&sessionid=$_a');
      _gone('plain sessionid=$_a and enc sessionid%3D$_b');
    });
    test('plain CDN query + encoded cookie', () {
      _gone(
        'https://scontent.cdninstagram.com/a.jpg?oh=$_a and sessionid%253D$_b',
      );
    });
    test('encoded cookie header line', () {
      _gone('cookie: %73essionid=$_b; a=%3Bb');
    });
    test('secret that exists only after decoding is returned redacted', () {
      for (final s in [
        'sessionid%3D$_a',
        '%73essionid=$_a',
        r'{"sessionid":"'
            '$_a"}',
        'sessionid&#61;$_a',
        '${_enc('sessionid=$_a', 3)}',
        'ｓｅｓｓｉｏｎｉｄ=$_a',
        'session​id=$_a',
      ]) {
        _gone(s);
      }
    });
    test('no secret: original text is returned untouched', () {
      const t = 'GET /a%20b?x=%41&y=\\u0041 100% &#65; done';
      expect(Redactor.redact(t), t);
    });
  });

  group('over-redaction from decoding is bounded to the value token', () {
    test('harmless text that decodes into a key only masks that value', () {
      final out = Redactor.redact('hello %70in%3D1234 world');
      expect(out, 'hello pin=[REDACTED] world');
    });
    test('long harmless text with one encoded key keeps the rest', () {
      final filler = List.generate(50, (i) => 'word$i').join(' ');
      final out = Redactor.redact('$filler mid%3Dx $filler');
      expect(out, contains('word0'));
      expect(out, contains('word49'));
      expect(out.length, greaterThan(filler.length * 2 - 20));
    });
    test('invalid / partial escapes are left alone', () {
      for (final t in [
        '%2',
        '%',
        r'\u00',
        '&#99999;',
        '&#x1F600;',
        '100%',
        '%zz',
      ]) {
        expect(Redactor.redact(t), t);
      }
    });
    test('control characters are never produced by decoding', () {
      expect(Redactor.redact('sessionid=%0Aabc%0Dxyz'), isNot(contains('\n')));
      expect(Redactor.redact('sessionid=\\u000Aabc'), isNot(contains('\n')));
    });
  });

  group('encoding depth', () {
    for (var n = 1; n <= 3; n++) {
      test('$n-times encoded key=value is redacted', () {
        _gone(_enc('sessionid=$_a', n));
      });
    }
    test('4-times encoded key=value: value is still redacted', () {
      _gone(_enc('sessionid=$_a', 4));
    });
    test('4-times encoded CDN URL', () {
      _gone(_enc('https://scontent.cdninstagram.com/a.jpg?oh=$_a', 4));
    });
    test('5- and 6-times encoded key=value', () {
      _gone(_enc('sessionid=$_a', 5));
      _gone(_enc('sessionid=$_a', 6));
    });
  });

  group('N1: decoded text can split a value (regression vs round 1)', () {
    for (final sep in ['%3B', '%2C', '%26', '%22', '%20']) {
      test('sessionid=<secret>$sep<secret>', () {
        _gone('sessionid=${_a}x$sep$_b');
      });
    }
    test(
      'round-1 behaviour for the same inputs (control): :-joined value is fine',
      () {
        _gone('sessionid=123%3A${_a}%3A27%3A$_b');
      },
    );
    test('unknown CDN param after %20', () {
      _gone(
        'https://scontent.cdninstagram.com/a.jpg?ccb=1%20&xyz=$_a sessionid%3D$_b',
      );
    });
  });

  group('bare-key rule', () {
    test('values of 6+ chars are redacted for each key', () {
      for (final k in [
        'sessionid',
        'session_id',
        'csrftoken',
        'ds_user_id',
        'enc_password',
      ]) {
        _gone('$k $_a');
        _gone('$k\t$_a');
      }
    });
    test('documented limits: values under 6 chars and newline-separated values stay', () {
      expect(Redactor.redact('sessionid abc'), 'sessionid abc');
      expect(Redactor.redact('ds_user_id 12345'), 'ds_user_id 12345');
      expect(Redactor.redact('sessionid\nabcdefgh'), 'sessionid\nabcdefgh');
    });
    test('N3 minor: prose after a bare key is over-redacted', () {
      expect(Redactor.redact('sessionid expired'), 'sessionid [REDACTED]');
      expect(Redactor.redact('csrftoken invalid'), 'csrftoken [REDACTED]');
    });
    test('key=value form has no minimum length', () {
      expect(Redactor.redact('sessionid=a'), 'sessionid=[REDACTED]');
      expect(Redactor.redact('ds_user_id=12'), 'ds_user_id=[REDACTED]');
    });
  });

  group('ReDoS (round 2) worst case is reported', () {
    test('100 KB adversarial inputs incl. decoder inputs', () {
      const n = 100000;
      final inputs = <String, String>{
        'percent run': '%41' * (n ~/ 3),
        'percent-25 run': '%25' * (n ~/ 3),
        'percent-25 + key': '%25253D' * (n ~/ 7),
        'unicode escapes': r'A' * (n ~/ 6),
        'html entities': '&#65;' * (n ~/ 5),
        'zero-width': '​' * n,
        'fullwidth': 'ａ' * n,
        'key + percent': 'sessionid%3D${'%41' * (n ~/ 3)}',
        'bare key repeated': 'sessionid ' * (n ~/ 10),
        'bare key + long value': 'sessionid ${'a' * n}',
        'unterminated quote': 'sessionid="${r'a\' * (n ~/ 2)}',
        'repeated key+quote': 'sessionid="a ' * (n ~/ 13),
        'whitespace': ' \t' * (n ~/ 2),
        'escaped quotes': r'\"' * (n ~/ 2),
        'pin repeated': 'pin=' * (n ~/ 4),
        'url many': 'https://a.cdninstagram.com/?' * (n ~/ 28),
        'bearer repeated': 'Bearer ' * (n ~/ 7),
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
      print('REDOS worst=$worst ms ($worstName)');
      expect(
        worst,
        lessThan(5000),
      ); // load-tolerant; catastrophic backtracking would take far longer
    });
    test('1 MB input stays under 5 s (linearity check)', () {
      final sw = Stopwatch()..start();
      Redactor.redact('%25253D sessionid ' * 60000);
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('line separators', () {
    late Directory tmp;
    late FileDiagnosticLog log;
    late RotatingLogFile file;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('storize_qa_r2_');
      file = RotatingLogFile(Directory('${tmp.path}/l'));
      log = FileDiagnosticLog(
        file: file,
        clock: FakeClock(DateTime.utc(2026, 11, 19)),
      );
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    const seps = ['\n', '\r', '\r\n', '\u000B', '\u000C', '\u0085', ' ', ' '];
    const forged = '2026-11-19T00:00:00.000Z ERROR [crash] forged';

    test('tag with any line separator stays on one line', () {
      for (final s in seps) {
        log.log(LogLevel.info, 'a${s}b$s$forged', 'm');
      }
      final text = file.current.readAsStringSync();
      for (final s in seps.skip(2)) {
        expect(text, isNot(contains(s)), reason: 'raw ${s.codeUnits} in log');
      }
      // Each call produced exactly one physical line (split on \n only).
      expect(text.split('\n').where((l) => l.isNotEmpty).length, seps.length);
    });

    test('N4 minor: U+0085 (NEL) in the tag is written raw', () {
      log.log(LogLevel.info, 'a\u0085b', 'm');
      expect(file.current.readAsStringSync(), isNot(contains('\u0085')));
    });

    test('message, error and stack separators are all indented', () {
      for (final s in seps) {
        log.log(
          LogLevel.info,
          't',
          'm1${s}2026 INFO [x] fake',
          error: StateError('e1${s}2026 INFO [x] fake'),
          stack: StackTrace.fromString('s1${s}2026 INFO [x] fake'),
        );
      }
      final lines = file.current
          .readAsStringSync()
          .split('\n')
          .where((l) => l.isNotEmpty);
      final starts = lines.where((l) => l.startsWith('2026-')).length;
      expect(
        starts,
        seps.length,
        reason: 'only real entries start at column 0',
      );
      expect(file.current.readAsStringSync(), isNot(contains(' ')));
      expect(file.current.readAsStringSync(), isNot(contains('\u0085')));
    });

    test('secret is redacted before indentation, and encoded breaks cannot hide it', () {
      log.log(LogLevel.info, 't', 'x sessionid=$_a\r\ncookie: a=$_b');
      expect(file.current.readAsStringSync(), isNot(contains('ZZQA')));
    });
  });
}
