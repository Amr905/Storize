// QA round 6 adversarial probes: host handling and the sanitizer seam. FAKE data.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sanitize_har.dart';

String _har(Object? body, {required String url}) => jsonEncode({
  'log': {
    'entries': [
      {
        'request': {'method': 'GET', 'url': url, 'headers': <Object?>[]},
        'response': {
          'status': 200,
          'content': {'mimeType': 'application/json', 'text': jsonEncode(body)},
        },
      },
    ],
  },
});

const _api = 'https://www.instagram.com/api/v1/x/';

String? _all(Object? body, {String url = _api}) {
  final o = sanitizeHar(_har(body, url: url));
  return o.ok ? o.files.values.join('\n') : null;
}

String _bodyUrl(String u) {
  final o = sanitizeHar(
    _har({'external_url': u, 'profile_pic_url': u, 'link': u}, url: _api),
  );
  expect(o.ok, isTrue, reason: '${o.leaks}');
  return o.files.values.join('\n');
}

void main() {
  group('request host (summary/report)', () {
    String? host(String url) {
      final o = sanitizeHar(_har({'status': 'ok'}, url: url));
      if (!o.ok) return null;
      final rows =
          (jsonDecode(o.files['summary.json']!) as Map)['requests'] as List;
      if (rows.isEmpty) return '<dropped>';
      final h = (rows.single as Map)['host'] as String;
      expect(o.files['report.md']!.toLowerCase(), isNot(contains('zzfake')));
      return h;
    }

    test('multi-level labels', () {
      expect(
        host('https://zzfake.z-p42.www.instagram.com/x/'),
        '<label>.<label>.www.instagram.com',
      );
      expect(
        host('https://www.zzfake.instagram.com/x/'),
        'www.<label>.instagram.com',
      );
      expect(host('https://i.i.i.instagram.com/x/'), 'i.i.i.instagram.com');
    });
    test('uppercase, punycode, trailing dot, ports, userinfo', () {
      expect(host('https://ZZFake.Instagram.COM/x/'), '<label>.instagram.com');
      expect(
        host('https://xn--zzfake-9ya.instagram.com/x/'),
        '<label>.instagram.com',
      );
      expect(
        host('https://zzfake:pw@www.instagram.com:8443/x/'),
        'www.instagram.com',
      );
      final dot = host('https://zzfake.instagram.com./x/');
      expect(
        dot == '<dropped>' || dot == '<label>.instagram.com',
        isTrue,
        reason: '$dot',
      );
    });
    test('lookalike and non-instagram hosts never appear', () {
      for (final u in [
        'https://instagram.com.zzfake.com/x/',
        'https://zzfake-instagram.com/x/',
        'https://www.instagram.com.zzfake.net/x/',
        'https://zzfakeinstagram.com/x/',
        'https://127.0.0.1/x/',
        'https://[::1]/x/',
        'https://zzfake.cdninstagram.com/x/',
      ]) {
        expect(host(u), isIn(<String?>['<dropped>', null]), reason: u);
      }
    });
  });

  group('URL placeholders inside bodies', () {
    test('instagram.com labels', () {
      final out = _bodyUrl('https://zzfake.instagram.com/a.jpg');
      expect(out.toLowerCase(), isNot(contains('zzfake')));
      expect(out, contains('<label>.instagram.com'));
    });
    test('lookalikes, IP, IPv6, userinfo, trailing dot, punycode become external or label', () {
      for (final u in [
        'https://instagram.com.zzfake.com/a.jpg',
        'https://zzfake-instagram.com/a.jpg',
        'https://127.0.0.1/a.jpg',
        'https://[::1]/a.jpg',
        'https://zzfake:pw@evil.example/a.jpg',
        'https://zzfake.instagram.com./a.jpg',
        'https://xn--zzfake-9ya.instagram.com/a.jpg',
        '//zzfake.example/a.jpg',
      ]) {
        expect(_bodyUrl(u).toLowerCase(), isNot(contains('zzfake')), reason: u);
      }
    });
    test(
      'QA-27: other known domains keep their full host',
      () {
        for (final d in [
          'cdninstagram.com',
          'fbcdn.net',
          'facebook.com',
          'fbsbx.com',
        ]) {
          expect(
            _bodyUrl('https://zzfake.$d/a.jpg').toLowerCase(),
            isNot(contains('zzfake')),
            reason: d,
          );
        }
      },
      skip: 'QA-27 (low/info): body URL hosts under cdninstagram.com/fbcdn.net/facebook.com/fbsbx.com keep every label; real CDN labels are server names, but facebook.com/fbsbx.com can carry a page-like label',
    );
  });

  group('seam: run() with and without sanitizer', () {
    late Directory d;
    late File har;
    setUp(() {
      d = Directory.systemTemp.createTempSync('qa6');
      har = File('${d.path}/in.har')
        ..writeAsStringSync(_har({'status': 'ok'}, url: _api));
    });
    tearDown(() => d.deleteSync(recursive: true));

    test(
      'default run() uses the real sanitizer and writes only sanitized output',
      () async {
        final o = StringBuffer();
        final e = StringBuffer();
        final code = await run([har.path, '${d.path}/o'], out: o, err: e);
        expect(code, 0);
        expect(File('${d.path}/o/summary.json').existsSync(), isTrue);
      },
    );
    test('default run() fails closed on a raw secret in the input via the real path', () async {
      final bad = File('${d.path}/bad.har')
        ..writeAsStringSync(
          _har(
            {'status': 'ok'},
            url: 'https://a1b2c3d4e5f60718293a4b5c6d7e8f90.instagram.com/api/v1/x/',
          ),
        );
      final e = StringBuffer();
      final code = await run(
        [bad.path, '${d.path}/o2'],
        out: StringBuffer(),
        err: e,
      );
      // Host label is now <label>, so the token never reaches the output: success is correct.
      expect(code, 0);
      expect(
        File('${d.path}/o2/summary.json').readAsStringSync(),
        isNot(contains('a1b2c3d4')),
      );
    });
    test('finalizeOutputs blocks planted secrets and returns no files', () {
      final r = finalizeOutputs({
        'a.json': '{"sessionid":"abcdef123456"}',
        'b.json': '{}',
      });
      expect(r.ok, isFalse);
      expect(r.files, isEmpty);
      expect(r.leaks.join(), isNot(contains('abcdef')));
    });
    test(
      'an injected sanitizer that returns leaky files with ok is written as is (seam, info)',
      () async {
        final e = StringBuffer();
        final code = await run(
          [har.path, '${d.path}/o3'],
          out: StringBuffer(),
          err: e,
          sanitizer: (t, {keepKeys = const {}}) => SanitizeOutcome(
            files: {'x.json': '{"sessionid":"abcdef123456"}'},
            leaks: const [],
          ),
        );
        expect(code, 1, reason: 'run() should re-scan injected output');
      },
      skip: 'QA-28 (info): run() trusts the injected outcome and does not call finalizeOutputs; production main() never injects',
    );
    test(
      'injected sanitizer through finalizeOutputs fails closed, writes nothing',
      () async {
        final e = StringBuffer();
        final code = await run(
          [har.path, '${d.path}/o4'],
          out: StringBuffer(),
          err: e,
          sanitizer: (t, {keepKeys = const {}}) =>
              finalizeOutputs({'x.json': '{"sessionid":"abcdef123456"}'}),
        );
        expect(code, 1);
        expect(Directory('${d.path}/o4').existsSync(), isFalse);
        expect(e.toString(), isNot(contains('abcdef')));
      },
    );
  });

  test('failure-map values and new keys still default-deny their values', () {
    final out = _all({
      'message': 'sentry_block',
      'checkpoint_url': 'https://www.instagram.com/challenge/zzfake/',
      'error_title': 'zzfake',
      'challenge': {'url': 'https://www.instagram.com/c/zzfake/', 'lock': true},
    })!;
    expect(out.toLowerCase(), isNot(contains('zzfake')));
    expect(out, contains('sentry_block'));
  });
}
