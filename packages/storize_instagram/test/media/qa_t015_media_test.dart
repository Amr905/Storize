// QA (T-015): adversarial checks of openMedia (CdnMediaOpener, DartIoCdnHttp).
// Tests marked "PIN" record a behaviour QA reports as a finding.
// ignore_for_file: specify_nonobvious_property_types, lines_longer_than_80_chars, use_raw_strings, only_throw_errors, cancel_subscriptions, cascade_invocations, discarded_futures
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/media/media.dart';

import '../platform/support.dart';

const _url = secretUrl;

CdnResponse _resp(
  List<List<int>> chunks, {
  int status = 200,
  String? range,
  int? length,
  Object? errorAfter,
}) => CdnResponse(
  status: status,
  contentRange: range,
  contentLength: length,
  body: bodyOf(chunks, errorAfter: errorAfter),
);

Future<(List<int>, Object?)> _collect(Stream<List<int>> s) async {
  final got = <int>[];
  Object? error;
  final done = Completer<void>();
  s.listen(
    got.addAll,
    onError: (Object e) => error ??= e,
    onDone: done.complete,
  );
  await done.future;
  return (got, error);
}

void main() {
  late FakeDiagnosticLog log;
  setUp(() => log = FakeDiagnosticLog());

  CdnMediaOpener opener(
    FakeCdnHttp http, {
    Duration idle = const Duration(seconds: 5),
  }) => CdnMediaOpener(http: http, log: log, idleTimeout: idle);

  group('Range resume', () {
    test(
      '200 instead of 206: the prefix is skipped across chunk boundaries '
      '(skip ends exactly on a boundary, inside a chunk, over many)',
      () async {
        final data = List<int>.generate(100, (i) => i);
        for (final skip in [1, 10, 29, 30, 31, 59, 60, 99]) {
          final http = FakeCdnHttp(
            (_, _) => _resp(
              [
                for (var i = 0; i < 100; i += 30)
                  data.sublist(i, min(i + 30, 100)),
              ],
              length: 100,
            ),
          );
          final (got, err) = await _collect(
            opener(http).open(_url, fromByte: skip),
          );
          expect(err, isNull, reason: 'skip $skip');
          expect(got, data.sublist(skip), reason: 'skip $skip');
          expect(http.headers.single, {'Range': 'bytes=$skip-'});
        }
      },
    );

    test(
      '200 whose body is exactly fromByte long: file already complete, empty Ok',
      () async {
        final http = FakeCdnHttp(
          (_, _) => _resp(
            [List<int>.filled(10, 1)],
            length: 10,
          ),
        );
        final (got, err) = await _collect(
          opener(http).open(_url, fromByte: 10),
        );
        expect(got, isEmpty);
        expect(err, isNull);
      },
    );

    test('truncated 200 during the skip phase is an error, never a short '
        'file', () async {
      final http = FakeCdnHttp(
        (_, _) => _resp([List<int>.filled(5, 1)], length: 100),
      );
      final (got, err) = await _collect(opener(http).open(_url, fromByte: 50));
      expect(got, isEmpty);
      expect(err, isA<MediaStreamFailure>());
    });

    test(
      '206 truncated against Content-Length is an error after valid bytes',
      () async {
        final http = FakeCdnHttp(
          (_, _) => _resp(
            [List<int>.filled(30, 7)],
            status: 206,
            range: 'bytes 50-99/200',
            length: 50,
          ),
        );
        final (got, err) = await _collect(
          opener(http).open(_url, fromByte: 50),
        );
        expect(got, hasLength(30));
        expect((err! as MediaStreamFailure).message, 'truncated');
      },
    );

    for (final range in [
      'bytes 49-99/200',
      'bytes 51-99/200',
      'bytes 0-99/200',
      'bytes */200',
      'items 50-99/200',
      'bytes 50-/200',
      '',
      'bytes 50',
    ]) {
      test(
        '206 with Content-Range "$range" on a resume at 50 is refused',
        () async {
          final http = FakeCdnHttp(
            (_, _) => _resp(
              [List<int>.filled(50, 7)],
              status: 206,
              range: range,
              length: 50,
            ),
          );
          final (got, err) = await _collect(
            opener(http).open(_url, fromByte: 50),
          );
          expect(got, isEmpty, reason: 'no wrong bytes may be written');
          expect(err, isA<MediaStreamFailure>());
        },
      );
    }

    test('416 on a resume is a failure with its status, not expiry, and the '
        'body is not read', () async {
      var cancelled = false;
      final http = FakeCdnHttp(
        (_, _) => CdnResponse(
          status: 416,
          body: bodyOf(
            [
              [1],
            ],
            stall: true,
            onCancel: () => cancelled = true,
          ),
        ),
      );
      final (_, err) = await _collect(opener(http).open(_url, fromByte: 200));
      expect(err, isA<MediaStreamFailure>());
      expect((err! as MediaStreamFailure).statusCode, 416);
      expect(err, isNot(isA<ExpiredMediaUrl>()));
      expect(cancelled, isTrue);
    });

    test('PIN (QA-T015-F3): a 206 for a request WITHOUT Range (fromByte 0) '
        'is accepted whatever its Content-Range start is', () async {
      final http = FakeCdnHttp(
        (_, _) => _resp(
          [List<int>.filled(10, 9)],
          status: 206,
          range: 'bytes 500-509/1000',
          length: 10,
        ),
      );
      final (got, err) = await _collect(opener(http).open(_url));
      expect(http.headers.single, isEmpty, reason: 'no Range was sent');
      // WANTED: a failure (range_mismatch). Current: wrong bytes accepted.
      expect(err, isNull);
      expect(got, hasLength(10));
    });

    test(
      'PIN (QA-T015-F4): a 206 without Content-Length that ends early is '
      'a success (silent short file); Content-Range total is unused',
      () async {
        final http = FakeCdnHttp(
          (_, _) => _resp(
            [List<int>.filled(10, 9)],
            status: 206,
            range: 'bytes 50-149/150',
          ),
        );
        final (got, err) = await _collect(
          opener(http).open(_url, fromByte: 50),
        );
        // WANTED: 'truncated' (100 bytes announced by Content-Range).
        expect(err, isNull);
        expect(got, hasLength(10));
      },
    );

    test('a 200 without Content-Length that ends early is undetectable but '
        'must not throw', () async {
      final http = FakeCdnHttp(
        (_, _) => _resp([List<int>.filled(10, 9)]),
      );
      final (got, err) = await _collect(opener(http).open(_url));
      expect(err, isNull);
      expect(got, hasLength(10));
    });

    test('a connection reset in the middle keeps the bytes already sent '
        'valid and ends with a failure with a fixed reason', () async {
      final http = FakeCdnHttp(
        (_, _) => _resp(
          [List<int>.filled(10, 1)],
          errorAfter: const SocketException('https://secret.example/ZZFAKE'),
        ),
      );
      final (got, err) = await _collect(opener(http).open(_url));
      expect(got, hasLength(10));
      expect((err! as MediaStreamFailure).message, 'socket');
      expect('$err', isNot(contains('ZZFAKE')));
    });

    test('resuming repeatedly always sends Range from the given offset and '
        'nothing else', () async {
      final http = FakeCdnHttp(
        (_, _) => _resp(
          [List<int>.filled(1, 0)],
          status: 206,
          range: 'bytes 7-7/8',
          length: 1,
        ),
      );
      for (var i = 0; i < 3; i++) {
        await _collect(opener(http).open(_url, fromByte: 7));
      }
      expect(http.headers, everyElement({'Range': 'bytes=7-'}));
    });
  });

  group('redirects and hosts', () {
    for (final status in [301, 302, 303, 307, 308]) {
      test(
        'HTTP $status is a failure; exactly one request, no body bytes',
        () async {
          final http = FakeCdnHttp(
            (_, _) => _resp([
              [1, 2, 3],
            ], status: status),
          );
          final (got, err) = await _collect(opener(http).open(_url));
          expect(http.uris, hasLength(1));
          expect(got, isEmpty);
          expect((err! as MediaStreamFailure).statusCode, status);
        },
      );
    }

    test('fuzz: whatever reaches the client is https, no user info, port '
        'none/443 and an allow-listed host', () async {
      final rnd = Random(15);
      const hosts = [
        'scontent.fbcdn.net',
        'evil.test',
        'fbcdn.net.evil.test',
        'evilfbcdn.net',
        'x.cdninstagram.com',
        'cdninstagram.com',
        '127.0.0.1',
        '[::1]',
        'localhost',
        'fbcdn.net.',
        '%66bcdn.net',
        'fbcdn%2Enet',
        'ＦＢＣＤＮ.net',
      ];
      const schemes = ['https', 'http', 'HTTPS', 'ftp', 'blob', 'file', ''];
      const users = ['', 'a@', 'fbcdn.net@', 'scontent.fbcdn.net:x@'];
      const ports = ['', ':443', ':80', ':8443', ':0'];
      const tails = [
        '/a.jpg',
        '',
        '/\\@evil.test/',
        '?h=.fbcdn.net',
        '#.fbcdn.net',
        '/a b',
        '/%0d%0aCookie:%20a',
      ];
      final http = FakeCdnHttp(
        (_, _) => _resp([
          [1],
        ]),
      );
      final o = opener(http);
      for (var i = 0; i < 3000; i++) {
        final scheme = schemes[rnd.nextInt(schemes.length)];
        final url =
            '${scheme.isEmpty ? '' : '$scheme://'}'
            '${users[rnd.nextInt(users.length)]}'
            '${hosts[rnd.nextInt(hosts.length)]}'
            '${ports[rnd.nextInt(ports.length)]}'
            '${tails[rnd.nextInt(tails.length)]}';
        await _collect(o.open(url));
      }
      for (final u in http.uris) {
        expect(u.scheme, 'https', reason: '$u');
        expect(u.userInfo, isEmpty, reason: '$u');
        expect(!u.hasPort || u.port == 443, isTrue, reason: '$u');
        expect(
          cdnDomains.any((d) => u.host == d || u.host.endsWith('.$d')),
          isTrue,
          reason: '$u',
        );
      }
      expect(http.uris, isNotEmpty);
    });

    for (final url in [
      '',
      ' https://scontent.fbcdn.net/x',
      '//scontent.fbcdn.net/x',
      'https:scontent.fbcdn.net/x',
      'https://scontent.fbcdn.net@evil.test/x',
      'https://evil.test\\@scontent.fbcdn.net/x',
      'https://scontent.fbcdn.net.evil.test/x',
      'https://evil.test/?u=https://scontent.fbcdn.net/x',
    ]) {
      test('refused without a request: "$url"', () async {
        final http = FakeCdnHttp((_, _) => throw StateError('requested'));
        final (_, err) = await _collect(opener(http).open(url));
        expect(http.uris, isEmpty);
        expect((err! as MediaStreamFailure).message, 'url_rejected');
      });
    }
  });

  group('no URL in errors or logs, whatever fails', () {
    final thrown = <String, Object>{
      'SocketException': const SocketException('https://secret.example/ZZFAKE'),
      'HandshakeException': const HandshakeException('ZZFAKE secret'),
      'FormatException': const FormatException('ZZFAKE'),
      'StateError': StateError('ZZFAKE'),
      'TransportException': const TransportException('socket'),
      'String': 'ZZFAKE https://secret.example',
    };
    for (final MapEntry(key: name, value: error) in thrown.entries) {
      test('client throws $name', () async {
        final http = FakeCdnHttp((_, _) => throw error);
        final (_, err) = await _collect(opener(http).open(_url));
        expect('$err', isNot(contains('ZZFAKE')));
        expect(logText(log), isNot(contains('ZZFAKE')));
        expect(logText(log), isNot(contains('secret')));
      });
      test('body errors with $name', () async {
        final http = FakeCdnHttp(
          (_, _) => _resp([
            [1],
          ], errorAfter: error),
        );
        final (_, err) = await _collect(opener(http).open(_url));
        expect('$err', isNot(contains('ZZFAKE')));
        expect(logText(log), isNot(contains('ZZFAKE')));
      });
    }

    test('every status keeps URL, host, query and path out of the error and '
        'the log', () async {
      for (final status in [
        201,
        204,
        301,
        400,
        401,
        403,
        404,
        410,
        416,
        429,
        500,
        503,
      ]) {
        final http = FakeCdnHttp((_, _) => _resp([], status: status));
        final (_, err) = await _collect(opener(http).open(_url));
        final text = '$err ${logText(log)}';
        for (final needle in ['ZZFAKE', 'scontent', 'fbcdn', 'sig=']) {
          expect(text, isNot(contains(needle)), reason: 'status $status');
        }
      }
    });
  });

  group('backpressure and long streams', () {
    test('a slow consumer never lets the producer run ahead by more than a '
        'few chunks (64 MB, lazily produced)', () async {
      var produced = 0;
      var consumed = 0;
      var maxLag = 0;
      Stream<List<int>> body() async* {
        for (var i = 0; i < 1024; i++) {
          produced++;
          yield _chunk64k;
        }
      }

      final http = FakeCdnHttp(
        (_, _) => CdnResponse(
          status: 200,
          body: body(),
          contentLength: 1024 * 65536,
        ),
      );
      await for (final c in opener(http).open(_url)) {
        consumed++;
        expect(c, hasLength(65536));
        maxLag = max(maxLag, produced - consumed);
        if (consumed % 64 == 0) await Future<void>.delayed(Duration.zero);
      }
      expect(consumed, 1024);
      expect(maxLag, lessThanOrEqualTo(4), reason: 'lag was $maxLag chunks');
    });

    test(
      'the idle timeout does not fire while the consumer is paused',
      () async {
        final c = StreamController<List<int>>();
        final http = FakeCdnHttp(
          (_, _) => CdnResponse(status: 200, body: c.stream, contentLength: 4),
        );
        final got = <int>[];
        final done = Completer<void>();
        Object? error;
        late StreamSubscription<List<int>> sub;
        sub = opener(http, idle: const Duration(milliseconds: 80))
            .open(_url)
            .listen(
              (d) {
                got.addAll(d);
                if (got.length == 2) sub.pause();
              },
              onError: (Object e) => error = e,
              onDone: done.complete,
            );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.add([1, 2]);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(error, isNull, reason: 'paused time is not idle time');
        sub.resume();
        c.add([3, 4]);
        await c.close();
        await done.future;
        expect(got, [1, 2, 3, 4]);
      },
    );

    test('cancelling during the skip phase closes the body and emits '
        'nothing more', () async {
      var cancelled = false;
      final http = FakeCdnHttp(
        (_, _) => CdnResponse(
          status: 200,
          body: bodyOf(
            [
              [1, 2, 3],
            ],
            stall: true,
            onCancel: () => cancelled = true,
          ),
        ),
      );
      final got = <int>[];
      final sub = opener(http).open(_url, fromByte: 100).listen(got.addAll);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(cancelled, isTrue);
      expect(got, isEmpty);
    });
  });

  group('DartIoCdnHttp on a real local server', () {
    late HttpServer server;
    late HttpServer other;
    final seen = <HttpHeaders>[];
    var otherHits = 0;

    setUp(() async {
      seen.clear();
      otherHits = 0;
      other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      other.listen((r) {
        otherHits++;
        r.response
          ..write('x')
          ..close();
      });
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((r) {
        seen.add(r.headers);
        if (r.uri.path == '/redir') {
          r.response
            ..statusCode = 302
            ..headers.set('location', 'http://127.0.0.1:${other.port}/x')
            ..close();
        } else {
          r.response
            ..statusCode = 200
            ..write('abc')
            ..close();
        }
      });
    });
    tearDown(() async {
      await server.close(force: true);
      await other.close(force: true);
    });

    test('sends no Cookie, Authorization or session header; only Range when '
        'given', () async {
      final c = DartIoCdnHttp();
      final res = await c.get(
        Uri.parse('http://127.0.0.1:${server.port}/f'),
        headers: {'Range': 'bytes=1-'},
      );
      await res.body.drain<void>();
      final h = seen.single;
      expect(h.value('cookie'), isNull);
      expect(h.value('authorization'), isNull);
      expect(h.value('x-ig-app-id'), isNull);
      expect(h.value('range'), 'bytes=1-');
      final names = <String>[];
      h.forEach((n, _) => names.add(n));
      expect(
        names.toSet().difference({
          'range',
          'host',
          'accept-encoding',
          'user-agent',
        }),
        isEmpty,
        reason: 'unexpected headers: $names',
      );
    });

    test('a 302 to another host is NOT followed (the other server is never '
        'hit)', () async {
      final res = await DartIoCdnHttp().get(
        Uri.parse('http://127.0.0.1:${server.port}/redir'),
      );
      await res.body.drain<void>();
      expect(res.status, 302);
      expect(otherHits, 0);
      expect(seen, hasLength(1));
    });
  });
}

final List<int> _chunk64k = List<int>.filled(65536, 0);
