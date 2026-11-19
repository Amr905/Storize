import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/update/update.dart';

/// QA adversarial tests for T-023. No network: a fake dio adapter only.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}

final String _sha = 'cd' * 32;

ResponseBody _raw(String text, {int status = 200}) => ResponseBody.fromString(
  text,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

UpdateChecker _serving(String text, {Duration? timeout}) => UpdateChecker(
  dio: Dio()..httpClientAdapter = _Adapter((_) async => _raw(text)),
  timeout: timeout ?? const Duration(seconds: 10),
);

String _rel({Object? tag, Object? html, Object? body}) => jsonEncode({
  'tag_name': tag ?? 'v0.2.0',
  'html_url': html ?? 'https://github.com/Amr905/Storize/releases/tag/v0.2.0',
  'body': body,
});

Future<UpdateState> _run(String json, {String current = '0.1.0'}) =>
    _serving(json).checkForUpdate(currentVersion: current);

void main() {
  group('never throws: hostile payloads', () {
    final payloads = <String, String>{
      'empty': '',
      'null json': 'null',
      'array': '[]',
      'string': '"x"',
      'number': '42',
      'truncated json': '{"tag_name": "v9.0.0", ',
      'tag number': jsonEncode({'tag_name': 5, 'html_url': 'https://x.y'}),
      'tag null': jsonEncode({'tag_name': null, 'html_url': 'https://x.y'}),
      'tag list': jsonEncode({
        'tag_name': ['v9.0.0'],
        'html_url': 'https://x.y',
      }),
      'html number': jsonEncode({'tag_name': 'v9.0.0', 'html_url': 7}),
      'html map': jsonEncode({
        'tag_name': 'v9.0.0',
        'html_url': <String, Object>{},
      }),
      'body number': _rel(tag: 'v9.0.0', body: 12345),
      'body list': _rel(tag: 'v9.0.0', body: ['sha256: x']),
      'body map': _rel(tag: 'v9.0.0', body: {'a': 1}),
      'body null': _rel(tag: 'v9.0.0'),
      'bad uri': _rel(tag: 'v9.0.0', html: 'https://%zz:::'),
      'bad uri 2': _rel(tag: 'v9.0.0', html: 'http://[::1'),
      'nested map': jsonEncode({
        'a': {'b': 1},
      }),
    };
    for (final MapEntry(key: name, value: text) in payloads.entries) {
      test(name, () async {
        final r = await _run(text);
        expect(r, isA<UpdateState>());
      });
    }

    test('huge body (5 MB of junk lines) does not throw or hang', () async {
      final big = List.filled(100000, 'x' * 50).join('\n');
      final sw = Stopwatch()..start();
      final r = await _run(_rel(tag: 'v0.2.0', body: big));
      expect(r, isA<UpdateAvailable>());
      expect((r as UpdateAvailable).sha256, isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('huge body with sha line at the very end is still found', () async {
      final big = '${List.filled(50000, 'y' * 40).join('\n')}\nsha256: $_sha';
      final r = await _run(_rel(body: big)) as UpdateAvailable;
      expect(r.sha256, _sha);
    });

    test('body that is a 1 MB single line with no colon', () async {
      final r = await _run(_rel(body: 'z' * 1000000));
      expect(r, isA<UpdateAvailable>());
    });
  });

  group('version edge cases (tag)', () {
    for (final tag in [
      'v999999999999999999999.0.0', // int overflow
      'v0.999999999999999999999.0',
      'vv1.2.3',
      'v١.٢.٣', // arabic-indic digits
      'v１.２.３', // fullwidth digits
      'v-1.2.3',
      'v1.-2.3',
      'v1..3',
      'v1.2.3.',
      'v.1.2.3',
      'v1.2.3-',
      'v1.2.3+',
      'v1.2.3-+',
      'v1.2.3-a..b',
      'v1.2.3-ü',
      '',
      ' ',
      'latest',
      '\u0000',
    ]) {
      test('tag ${jsonEncode(tag)} -> none, no throw', () async {
        expect(await _run(_rel(tag: tag)), same(UpdateState.none));
      });
    }

    test('leading zeros are accepted today (SemVer forbids them)', () async {
      // Documents current behavior; reported as a Low finding.
      expect(SemanticVersion.tryParse('v01.2.3'), isNotNull);
      expect(SemanticVersion.tryParse('v01.2.3')!.major, 1);
    });

    test('huge current version is rejected without throwing', () async {
      final r = await _run(
        _rel(tag: 'v9.0.0'),
        current: '99999999999999999999999.0.0',
      );
      expect(r, same(UpdateState.none));
    });

    test('hostile currentVersion strings do not throw', () async {
      for (final c in ['', 'abc', '1', '-', '\u0000', '١.٢.٣', 'v', '1.2.3-']) {
        expect(
          await _run(_rel(tag: 'v9.0.0'), current: c),
          same(UpdateState.none),
        );
      }
    });
  });

  group('html_url security', () {
    Future<UpdateState> withUrl(String u) => _run(_rel(html: u));

    test('http and non-web schemes are rejected', () async {
      for (final u in [
        'http://github.com/Amr905/Storize/releases/tag/v0.2.0',
        'javascript:alert(1)',
        'intent://evil#Intent;end',
        'file:///etc/passwd',
        'market://details?id=x',
        '//github.com/x',
        '/relative',
        '',
      ]) {
        expect(await withUrl(u), same(UpdateState.none), reason: u);
      }
    });

    test(
      'FINDING: any https host is accepted (not restricted to github.com)',
      () async {
        // Documents current behavior. Recommendation: pin the host/path.
        final r = await withUrl('https://evil.example/phish');
        expect(r, isA<UpdateAvailable>());
        expect((r as UpdateAvailable).url.host, 'evil.example');
      },
    );

    test('FINDING: userinfo lookalike host is accepted', () async {
      final r = await withUrl('https://github.com@evil.example/x');
      expect(r, isA<UpdateAvailable>());
      expect((r as UpdateAvailable).url.host, 'evil.example');
    });
  });

  group('sha256 / min-supported body parsing', () {
    Future<UpdateState> withBody(String b, {String current = '0.1.0'}) => _run(
      _rel(tag: 'v0.5.0', body: b),
      current: current,
    );

    test('trailing file name is ignored', () async {
      final r = await withBody('sha256: $_sha app-prod.apk') as UpdateAvailable;
      expect(r.sha256, _sha);
    });

    test('"<hex>  file" is not mistaken: hex must come first', () async {
      final r = await withBody('sha256: app-prod.apk $_sha') as UpdateAvailable;
      expect(r.sha256, isNull);
    });

    test(
      'multiple sha lines: first one wins, even when first is malformed',
      () async {
        final other = 'ef' * 32;
        final a =
            await withBody('sha256: $_sha\nsha256: $other') as UpdateAvailable;
        expect(a.sha256, _sha);
        final b =
            await withBody('sha256: nothex\nsha256: $other') as UpdateAvailable;
        expect(b.sha256, isNull); // later valid line is not used
      },
    );

    test('uppercase hex lowercased; 63 and 65 chars rejected', () async {
      final up =
          await withBody('SHA256: ${_sha.toUpperCase()}') as UpdateAvailable;
      expect(up.sha256, _sha);
      final s63 =
          await withBody('sha256: ${_sha.substring(1)}') as UpdateAvailable;
      expect(s63.sha256, isNull);
      final s65 = await withBody('sha256: ${_sha}0') as UpdateAvailable;
      expect(s65.sha256, isNull);
    });

    test(
      'sha embedded in prose or markdown decoration is not parsed',
      () async {
        for (final b in [
          'The sha256: $_sha is below',
          '- sha256: $_sha',
          '**sha256:** $_sha',
          '`sha256: $_sha`',
          'sha256 $_sha',
          'sha256=$_sha',
        ]) {
          final r = await withBody(b) as UpdateAvailable;
          expect(r.sha256, isNull, reason: b);
        }
      },
    );

    test('CRLF and indentation are tolerated', () async {
      final r = await withBody(
        'Notes\r\n  sha256: $_sha\r\nmin-supported: 0.3.0\r\n',
      );
      expect(r, isA<UpdateRequired>());
      expect((r as UpdateRequired).sha256, _sha);
    });

    test('min-supported with v prefix, pre-release and garbage', () async {
      expect(await withBody('min-supported: v0.3.0'), isA<UpdateRequired>());
      expect(
        await withBody('min-supported: 0.3.0 (security)'),
        isA<UpdateRequired>(),
      );
      expect(await withBody('min-supported: abc'), isA<UpdateAvailable>());
      expect(await withBody('min-supported:'), isA<UpdateAvailable>());
      expect(
        await withBody('min-supported: 99999999999999999999.0.0'),
        isA<UpdateAvailable>(),
      );
    });

    test(
      'equality boundary: current == min-supported is not required',
      () async {
        expect(await withBody('min-supported: 0.1.0'), isA<UpdateAvailable>());
      },
    );

    test(
      'pre-release current below min-supported release is required',
      () async {
        expect(
          await withBody('min-supported: 0.1.0', current: '0.1.0-rc.1'),
          isA<UpdateRequired>(),
        );
      },
    );

    test('min-supported above remote tag, remote newer: required', () async {
      // Misconfigured release (min > tag). Current < min and remote > current.
      expect(await withBody('min-supported: 0.9.0'), isA<UpdateRequired>());
    });

    test(
      'remote not newer but current < min-supported -> none (documented)',
      () async {
        // Only possible when min-supported > tag and tag <= current, i.e. a
        // release-notes typo. Nothing newer exists to install.
        final r = await _run(
          _rel(tag: 'v0.1.0', body: 'min-supported: 0.9.0'),
        );
        expect(r, same(UpdateState.none));
      },
    );
  });

  group('errors and statuses', () {
    test('HTTP 403/404/429/500/302 and bad status yield none', () async {
      for (final s in [301, 302, 304, 400, 403, 404, 429, 500, 503]) {
        final c = UpdateChecker(
          dio: Dio()
            ..httpClientAdapter = _Adapter(
              (_) async => _raw(_rel(tag: 'v9.0.0'), status: s),
            ),
        );
        expect(
          await c.checkForUpdate(currentVersion: '0.1.0'),
          same(UpdateState.none),
          reason: '$s',
        );
      }
    });

    test(
      'adapter throws synchronously / asynchronously / non-Exception',
      () async {
        for (final f in <Future<ResponseBody> Function(RequestOptions)>[
          (_) => throw StateError('sync'),
          (_) async => throw const FormatException('async'),
          // Intentionally not an Error or Exception.
          // ignore: only_throw_errors
          (_) async => throw const _Odd(),
          (_) async => throw ArgumentError('x'),
          (_) async => throw TypeError(),
        ]) {
          final c = UpdateChecker(dio: Dio()..httpClientAdapter = _Adapter(f));
          expect(
            await c.checkForUpdate(currentVersion: '0.1.0'),
            same(UpdateState.none),
          );
        }
      },
    );

    test('invalid UTF-8 body yields none', () async {
      final c = UpdateChecker(
        dio: Dio()
          ..httpClientAdapter = _Adapter(
            (_) async => ResponseBody.fromBytes(
              [0xff, 0xfe, 0x7b, 0x7d],
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
          ),
      );
      expect(
        await c.checkForUpdate(currentVersion: '0.1.0'),
        same(UpdateState.none),
      );
    });

    test('request is a plain GET without credentials', () async {
      RequestOptions? seen;
      final c = UpdateChecker(
        dio: Dio()
          ..httpClientAdapter = _Adapter((o) async {
            seen = o;
            return _raw(_rel(tag: 'v0.1.0'));
          }),
      );
      await c.checkForUpdate(currentVersion: '0.1.0');
      expect(seen!.method, 'GET');
      expect(
        seen!.uri.toString(),
        'https://api.github.com/repos/Amr905/Storize/releases/latest',
      );
      expect(
        seen!.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        seen!.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('cookie')),
      );
    });
  });

  group('timeout is bounded and leaves no timers', () {
    testWidgets('adapter that never responds: result none after timeout', (
      tester,
    ) async {
      final never = Completer<ResponseBody>();
      final c = UpdateChecker(
        dio: Dio()..httpClientAdapter = _Adapter((_) => never.future),
        timeout: const Duration(seconds: 3),
      );
      UpdateState? result;
      unawaited(
        c.checkForUpdate(currentVersion: '0.1.0').then((v) => result = v),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(result, isNull, reason: 'still waiting before the timeout');
      await tester.pump(const Duration(seconds: 2));
      expect(result, same(UpdateState.none));
      // testWidgets fails here if a Timer is still pending.
    });

    testWidgets('fast success leaves no pending timer', (tester) async {
      final c = UpdateChecker(
        dio: Dio()..httpClientAdapter = _Adapter((_) async => _raw(_rel())),
        timeout: const Duration(seconds: 30),
      );
      UpdateState? result;
      unawaited(
        c.checkForUpdate(currentVersion: '0.1.0').then((v) => result = v),
      );
      for (var n = 0; n < 20 && result == null; n++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(result, isA<UpdateAvailable>());
    });

    test(
      'real clock: never-responding adapter returns within ~timeout',
      () async {
        final never = Completer<ResponseBody>();
        final c = UpdateChecker(
          dio: Dio()..httpClientAdapter = _Adapter((_) => never.future),
          timeout: const Duration(milliseconds: 200),
        );
        final sw = Stopwatch()..start();
        final r = await c.checkForUpdate(currentVersion: '0.1.0');
        expect(r, same(UpdateState.none));
        expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );

    test('close() on injected dio is a no-op; on own dio is safe twice', () {
      final shared = Dio();
      UpdateChecker(dio: shared).close();
      // Injected client must remain usable (not closed): no throw on get setup.
      expect(() => shared.options, returnsNormally);
      UpdateChecker()
        ..close()
        ..close();
    });
  });
}

class _Odd {
  const _Odd();
}
