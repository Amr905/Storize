// DartIoCdnHttp against a loopback server: no cookies, Range passed, no
// redirect following, cancel closes the connection, errors lose their text.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/media/media.dart';

void main() {
  late HttpServer server;
  late List<HttpHeaders> seen;
  late Future<void> Function(HttpRequest) handler;

  setUp(() async {
    seen = [];
    handler = (r) async => r.response.close();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // ignore: cascade_invocations, two statements read better here.
    server.listen((r) async {
      seen.add(r.headers);
      await handler(r);
    });
  });
  tearDown(() => server.close(force: true));

  Uri url([String path = '/file']) =>
      Uri.parse('http://127.0.0.1:${server.port}$path');

  test(
    'GET with only the given headers: no Cookie, no Authorization',
    () async {
      handler = (r) async {
        r.response.add([1, 2, 3]);
        await r.response.close();
      };
      final client = DartIoCdnHttp();
      final res = await client.get(url(), headers: {'Range': 'bytes=2-'});
      expect(res.status, 200);
      expect([for (final c in await res.body.toList()) ...c], [1, 2, 3]);
      expect(seen.single.value('range'), 'bytes=2-');
      expect(seen.single.value('cookie'), isNull);
      expect(seen.single.value('authorization'), isNull);
      expect(seen.single.value('x-csrftoken'), isNull);
    },
  );

  test('a 206 reply carries Content-Range and Content-Length', () async {
    handler = (r) async {
      r.response
        ..statusCode = 206
        ..headers.set('content-range', 'bytes 2-3/4')
        ..contentLength = 2
        ..add([9, 9]);
      await r.response.close();
    };
    final res = await DartIoCdnHttp().get(url());
    expect(res.status, 206);
    expect(res.contentRange, 'bytes 2-3/4');
    expect(res.contentLength, 2);
    await res.body.drain<void>();
  });

  test('redirects are not followed', () async {
    handler = (r) async {
      r.response
        ..statusCode = 302
        ..headers.set('location', 'https://example.test/x');
      await r.response.close();
    };
    final res = await DartIoCdnHttp().get(url());
    expect(res.status, 302);
    await res.body.drain<void>();
    expect(seen, hasLength(1));
  });

  test('a refused connection is a TransportException without text', () async {
    final port = server.port;
    await server.close(force: true);
    try {
      await DartIoCdnHttp().get(Uri.parse('http://127.0.0.1:$port/ZZFAKE'));
      fail('should throw');
    } on TransportException catch (e) {
      expect(e.kind, 'socket');
      expect(e.toString(), isNot(contains('ZZFAKE')));
    }
  });

  test('a server that never answers is a timeout', () async {
    handler = (r) => Completer<void>().future;
    final client = DartIoCdnHttp(
      connectTimeout: const Duration(milliseconds: 50),
    );
    try {
      await client.get(url());
      fail('should throw');
    } on TransportException catch (e) {
      expect(e.kind, 'timeout');
    }
  });

  test('works end to end under the opener (allowlist aside)', () async {
    handler = (r) async {
      r.response.add(List.filled(1000, 7));
      await r.response.close();
    };
    final res = await DartIoCdnHttp().get(url());
    final opener = CdnMediaOpener(http: _Fixed(res));
    final bytes = [
      for (final c in await opener.open('https://x.fbcdn.net/a').toList()) ...c,
    ];
    expect(bytes, hasLength(1000));
  });
}

final class _Fixed implements CdnHttp {
  _Fixed(this.response);

  final CdnResponse response;

  @override
  Future<CdnResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async => response;
}
