// DartIoHttp against a local loopback server: no Instagram, no real data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';

void main() {
  late HttpServer server;
  late String base;
  final seen = <Map<String, Object?>>[];

  setUp(() async {
    seen.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    unawaited(
      server.forEach((req) async {
        final body = await utf8.decodeStream(req);
        seen.add({
          'method': req.method,
          'path': req.uri.path,
          'query': req.uri.query,
          'cookie': req.headers.value('cookie'),
          'ua': req.headers.value('user-agent'),
          'range': req.headers.value('range'),
          'type': req.headers.contentType?.mimeType,
          'body': body,
        });
        switch (req.uri.path) {
          case '/json':
            req.response
              ..headers.contentType = ContentType.json
              ..write('{"a":1}');
          case '/js':
            req.response
              ..headers.contentType = ContentType('text', 'javascript')
              ..write('{"a":2}');
          case '/limited':
            req.response
              ..statusCode = 429
              ..headers.set('retry-after', '45')
              ..write('{"message":"x"}');
          case '/redirect':
            req.response
              ..statusCode = 302
              ..headers.set('location', '/accounts/login/?next=ZZFAKE');
          case '/bytes':
            req.response
              ..statusCode = 206
              ..headers.contentType = ContentType('image', 'jpeg')
              ..add([0xFF, 0xD8, 0xFF]);
          case '/slow':
            await Future<void>.delayed(const Duration(seconds: 2));
          default:
            req.response.statusCode = 404;
        }
        await req.response.close();
      }),
    );
  });

  tearDown(() => server.close(force: true));

  IgRequest get(String path, {Map<String, String> headers = const {}}) =>
      IgRequest(
        method: IgMethod.get,
        uri: Uri.parse('$base$path'),
        headers: headers,
      );

  test('GET sends the headers and decodes JSON', () async {
    final reply = await DartIoHttp().send(
      get(
        '/json?x=1',
        headers: {'Cookie': 'a=ZZFAKE', 'User-Agent': 'ZZFAKE-UA'},
      ),
    );
    expect(reply.status, 200);
    expect(reply.json, {'a': 1});
    expect(seen.single['cookie'], 'a=ZZFAKE');
    expect(seen.single['ua'], 'ZZFAKE-UA');
    expect(seen.single['query'], 'x=1');
  });

  test('POST sends a form-encoded body', () async {
    final reply = await DartIoHttp().send(
      IgRequest(
        method: IgMethod.post,
        uri: Uri.parse('$base/json'),
        form: const {'doc_id': 'ZZFAKE', 'variables': '{"a":"b c"}'},
      ),
    );
    expect(reply.status, 200);
    expect(seen.single['type'], 'application/x-www-form-urlencoded');
    expect(Uri.splitQueryString(seen.single['body']! as String), {
      'doc_id': 'ZZFAKE',
      'variables': '{"a":"b c"}',
    });
  });

  test('a body that starts with { is JSON whatever the content type', () async {
    expect((await DartIoHttp().send(get('/js'))).json, {'a': 2});
  });

  test('429 carries Retry-After', () async {
    final reply = await DartIoHttp().send(get('/limited'));
    expect(reply.status, 429);
    expect(reply.retryAfter, const Duration(seconds: 45));
  });

  test(
    'redirects are not followed; only the path of Location is kept',
    () async {
      final reply = await DartIoHttp().send(get('/redirect'));
      expect(reply.status, 302);
      expect(reply.redirectPath, '/accounts/login/');
      expect(seen, hasLength(1));
    },
  );

  test('a binary reply has a content type and no JSON', () async {
    final reply = await DartIoHttp().send(
      get('/bytes', headers: {'Range': 'bytes=0-1023'}),
    );
    expect(reply.status, 206);
    expect(reply.contentType, 'image/jpeg');
    expect(reply.json, isNull);
    expect(seen.single['range'], 'bytes=0-1023');
  });

  test('timeout and a closed port are TransportException', () async {
    final slow = DartIoHttp(timeout: const Duration(milliseconds: 200));
    await expectLater(
      slow.send(get('/slow')),
      throwsA(
        isA<TransportException>().having((e) => e.kind, 'kind', 'timeout'),
      ),
    );
    final port = server.port;
    await server.close(force: true);
    await expectLater(
      DartIoHttp().send(
        IgRequest(
          method: IgMethod.get,
          uri: Uri.parse('http://127.0.0.1:$port/x'),
        ),
      ),
      throwsA(
        isA<TransportException>().having((e) => e.kind, 'kind', 'socket'),
      ),
    );
  });
}
