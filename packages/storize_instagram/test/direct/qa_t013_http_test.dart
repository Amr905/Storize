// QA (T-013): DartIoHttp against local servers. Tests marked `skip:` document
// a finding and assert the behaviour wanted after a fix.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';

IgRequest _get(String url, {Map<String, String> headers = const {}}) =>
    IgRequest(method: IgMethod.get, uri: Uri.parse(url), headers: headers);

void main() {
  late HttpServer server;
  late String base;
  final hits = <String>[];

  setUp(() async {
    hits.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    unawaited(
      server.forEach((req) async {
        hits.add(req.uri.path);
        switch (req.uri.path) {
          case '/to-target':
            req.response
              ..statusCode = 302
              ..headers.set('location', '$base/target?secret=ZZFAKE');
          case '/target':
            req.response.write('{"reached":true}');
          case '/retry-date':
            req.response
              ..statusCode = 429
              ..headers.set('retry-after', 'Wed, 21 Oct 2037 07:28:00 GMT')
              ..write('{}');
          case '/retry-huge':
            req.response
              ..statusCode = 429
              ..headers.set('retry-after', '99999999999')
              ..write('{}');
          case '/retry-neg':
            req.response
              ..statusCode = 429
              ..headers.set('retry-after', '-30')
              ..write('{}');
          case '/big-json':
            req.response.headers.contentType = ContentType.json;
            req.response.write('{"a":"');
            for (var i = 0; i < 40; i++) {
              req.response.write('x' * 100000);
            }
            req.response.write('"}');
          case '/ok-json':
            req.response.write('{"a":"${'y' * 200000}"}');
          case '/hang':
            await Future<void>.delayed(const Duration(seconds: 30));
          case '/drip':
            req.response.headers.contentType = ContentType.json;
            req.response.write('{"a":"');
            try {
              for (var i = 0; i < 100; i++) {
                req.response.write('z');
                await req.response.flush();
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
            } on Object {
              hits.add('drip-client-gone');
              return;
            }
          default:
            req.response.statusCode = 404;
        }
        try {
          await req.response.close();
        } on Object {
          // client went away
        }
      }),
    );
  });

  tearDown(() => server.close(force: true));

  test('a redirect is never followed (the target is not requested)', () async {
    final reply = await DartIoHttp().send(_get('$base/to-target'));
    expect(reply.status, 302);
    expect(reply.redirectPath, '/target', reason: 'path only, no query');
    expect(hits, ['/to-target']);
    expect(reply.toString(), isNot(contains('ZZFAKE')));
  });

  test('Retry-After: seconds are read; negative gives null', () async {
    expect(
      (await DartIoHttp().send(_get('$base/retry-neg'))).retryAfter,
      isNull,
    );
    final huge = await DartIoHttp().send(_get('$base/retry-huge'));
    expect(huge.retryAfter, const Duration(seconds: 99999999999));
  });

  test(
    'QA-F6: Retry-After as an HTTP-date should become a duration',
    () async {
      final reply = await DartIoHttp().send(_get('$base/retry-date'));
      expect(reply.retryAfter, isNotNull);
    },
  );

  test('a body over the cap: status kept, json null, memory bounded', () async {
    final reply = await DartIoHttp(maxBodyBytes: 1024 * 1024).send(
      _get('$base/big-json'),
    );
    expect(reply.status, 200);
    expect(reply.json, isNull);
    const classifier = FailureClassifier();
    expect(classifier.classify(reply), isNotNull);
  });

  test('a body under the cap is decoded (200 KB)', () async {
    final reply = await DartIoHttp(maxBodyBytes: 1024 * 1024).send(
      _get('$base/ok-json'),
    );
    expect((reply.json! as Map)['a'], hasLength(200000));
  });

  test('the timeout covers a server that never answers', () async {
    final watch = Stopwatch()..start();
    await expectLater(
      DartIoHttp(timeout: const Duration(milliseconds: 300))
          .send(_get('$base/hang?q=ZZFAKE_query')),
      throwsA(
        isA<TransportException>()
            .having((e) => e.kind, 'kind', 'timeout')
            .having((e) => e.toString(), 'text', isNot(contains('ZZFAKE'))),
      ),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test(
    'the timeout covers a body that drips forever (total, not idle)',
    () async {
      final watch = Stopwatch()..start();
      await expectLater(
        DartIoHttp(timeout: const Duration(milliseconds: 500))
            .send(_get('$base/drip')),
        throwsA(isA<TransportException>()),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    },
  );

  test(
    'QA-F7: after a timeout or the body cap the connection is closed (no '
    'socket leak)',
    () async {
      // A raw socket server sees the client leave (an HttpServer does not
      // notice a half-read response until it writes much more).
      final gone = <String>[];
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      raw.listen((s) {
        s.listen((_) {}, onDone: () => gone.add('closed'), onError: (_) {});
        // ignore: cascade_invocations, listen returns a subscription.
        s.add(
          utf8.encode(
            'HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n'
            'transfer-encoding: chunked\r\n\r\n',
          ),
        );
        final timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
          try {
            s.add(utf8.encode('64\r\n${'z' * 100}\r\n'));
          } on Object {
            t.cancel();
          }
        });
        unawaited(s.done.whenComplete(timer.cancel).catchError((_) {}));
      });
      final url = 'http://127.0.0.1:${raw.port}/drip';
      await expectLater(
        DartIoHttp(timeout: const Duration(milliseconds: 300)).send(_get(url)),
        throwsA(isA<TransportException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(gone, ['closed'], reason: 'closed after the timeout');
      final reply = await DartIoHttp(maxBodyBytes: 500).send(_get(url));
      expect(reply.status, 200);
      expect(reply.json, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(gone, ['closed', 'closed'], reason: 'closed at the cap');
      await raw.close();
    },
  );

  test('a closed port and a non-TLS server over https are TransportException '
      'without the URL or query in the text', () async {
    final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close();
    await expectLater(
      DartIoHttp().send(_get('http://127.0.0.1:$deadPort/x?cookie=ZZFAKE')),
      throwsA(
        isA<TransportException>().having(
          (e) => e.toString(),
          'text',
          allOf(isNot(contains('ZZFAKE')), isNot(contains('127.0.0.1'))),
        ),
      ),
    );
    // A plain HTTP server answering a TLS hello: handshake error.
    await expectLater(
      DartIoHttp().send(
        _get('https://127.0.0.1:${server.port}/x?token=ZZFAKE'),
      ),
      throwsA(
        isA<TransportException>().having(
          (e) => e.toString(),
          'text',
          isNot(contains('ZZFAKE')),
        ),
      ),
    );
  });

  test('a garbage (non-HTTP) answer is TransportException', () async {
    final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    raw.listen((s) {
      s.add(utf8.encode('NOT HTTP AT ALL\r\n\r\n'));
      unawaited(s.close());
    });
    await expectLater(
      DartIoHttp().send(_get('http://127.0.0.1:${raw.port}/x')),
      throwsA(isA<TransportException>()),
    );
    await raw.close();
  });

  test(
    'QA-F1b: a header value the platform refuses (newline in a cookie) must '
    'not surface as a raw exception carrying the value',
    () async {
      Object? error;
      try {
        await DartIoHttp().send(
          _get('$base/ok-json', headers: {'Cookie': 'sessionid=ZZFAKE\nx=1'}),
        );
      } on Object catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect(error, isA<TransportException>());
      expect(error.toString(), isNot(contains('ZZFAKE')));
    },
  );

  test(
    'what actually escapes for a bad header value (evidence for QA-F1)',
    () async {
      Object? error;
      try {
        await DartIoHttp().send(
          _get('$base/ok-json', headers: {'Cookie': 'sessionid=ZZFAKE\nx=1'}),
        );
      } on Object catch (e) {
        error = e;
      }
      // ignore: avoid_print, evidence for the review
      print(
        'ESCAPED_TYPE=${error.runtimeType} '
        'CONTAINS_VALUE=${error.toString().contains('ZZFAKE')}',
      );
      expect(error, isNotNull);
    },
  );

  test(
    'CDN-style request: only the given headers are sent (no cookies)',
    () async {
      final seen = <String, String?>{};
      final s2 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      s2.listen((r) async {
        seen['cookie'] = r.headers.value('cookie');
        seen['range'] = r.headers.value('range');
        await r.response.close();
      });
      await DartIoHttp().send(
        _get(
          'http://127.0.0.1:${s2.port}/f.jpg',
          headers: const {'Range': 'bytes=0-1023'},
        ),
      );
      expect(seen['cookie'], isNull);
      expect(seen['range'], 'bytes=0-1023');
      await s2.close(force: true);
    },
  );
}
