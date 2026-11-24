// T-015 AC3: openMedia streams a CDN file with a plain GET, Range resume, no
// cookies, 403/410 as ExpiredMediaUrl, host allowlist, nothing governed, and
// no URL in any log.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/media/media.dart';

import '../platform/support.dart';

const String _okUrl = secretUrl;

CdnResponse _ok(
  List<List<int>> chunks, {
  int status = 200,
  String? range,
  int? length,
  Object? errorAfter,
  bool stall = false,
  void Function()? onCancel,
}) => CdnResponse(
  status: status,
  contentRange: range,
  contentLength: length,
  body: bodyOf(
    chunks,
    errorAfter: errorAfter,
    stall: stall,
    onCancel: onCancel,
  ),
);

Future<List<int>> _bytes(Stream<List<int>> s) async => [
  for (final c in await s.toList()) ...c,
];

/// The bytes before the first error, and that error (null if none).
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

Future<Object?> _error(Stream<List<int>> s) async {
  try {
    await s.drain<void>();
  } on Object catch (e) {
    return e;
  }
  return null;
}

void main() {
  late FakeDiagnosticLog log;
  setUp(() => log = FakeDiagnosticLog());

  CdnMediaOpener opener(
    FakeCdnHttp http, {
    Duration response = const Duration(seconds: 5),
    Duration idle = const Duration(seconds: 5),
  }) => CdnMediaOpener(
    http: http,
    log: log,
    responseTimeout: response,
    idleTimeout: idle,
  );

  group('AC3 plain GET, no cookies', () {
    test(
      'streams the whole body; the only request is a GET with no headers',
      () async {
        final http = FakeCdnHttp(
          (_, _) => _ok([
            [1, 2],
            [3],
          ], length: 3),
        );
        final bytes = await _bytes(opener(http).open(_okUrl));
        expect(bytes, [1, 2, 3]);
        expect(http.uris.single.toString(), _okUrl);
        expect(http.headers.single, isEmpty);
      },
    );

    test(
      'never sends cookies, tokens or any session header, resume or not',
      () async {
        final http = FakeCdnHttp(
          (_, _) => _ok([
            [1],
          ]),
        );
        await _bytes(opener(http).open(_okUrl));
        // ignore: avoid_redundant_argument_values, the explicit default.
        await _bytes(opener(http).open(_okUrl, fromByte: 0));
        for (final h in http.headers) {
          expect(
            h.keys.map((k) => k.toLowerCase()),
            everyElement(isIn(['range'])),
          );
        }
      },
    );
  });

  group('AC3 Range resume', () {
    test(
      'fromByte > 0 sends Range: bytes=N- and streams the 206 body',
      () async {
        final http = FakeCdnHttp(
          (_, _) => _ok(
            [
              [5, 6, 7],
            ],
            status: 206,
            range: 'bytes 4-6/7',
          ),
        );
        final bytes = await _bytes(opener(http).open(_okUrl, fromByte: 4));
        expect(http.headers.single, {'Range': 'bytes=4-'});
        expect(bytes, [5, 6, 7]);
      },
    );

    test('fromByte 0 sends no Range header', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok([
          [1],
        ]),
      );
      await _bytes(opener(http).open(_okUrl));
      expect(http.headers.single.containsKey('Range'), isFalse);
    });

    test('a 200 that ignored Range has its first fromByte bytes skipped, '
        'across chunk borders', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok([
          [0, 1, 2],
          [3, 4],
          [5, 6, 7, 8],
        ], length: 9),
      );
      final bytes = await _bytes(opener(http).open(_okUrl, fromByte: 4));
      expect(bytes, [4, 5, 6, 7, 8]);
    });

    test('a 200 shorter than fromByte is range_beyond_end', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok([
          [0, 1],
        ], length: 2),
      );
      final e = await _error(opener(http).open(_okUrl, fromByte: 10));
      expect(e, isA<MediaStreamFailure>());
      expect((e! as MediaStreamFailure).message, 'range_beyond_end');
    });

    test('a 206 whose Content-Range starts elsewhere is range_mismatch, no '
        'bytes emitted', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok(
          [
            [9, 9],
          ],
          status: 206,
          range: 'bytes 0-1/2',
        ),
      );
      final (got, error) = await _collect(
        opener(http).open(_okUrl, fromByte: 4),
      );
      expect(got, isEmpty);
      expect((error! as MediaStreamFailure).message, 'range_mismatch');
    });

    test('a 206 without Content-Range on a resume is refused', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok([
          [9],
        ], status: 206),
      );
      final e = await _error(opener(http).open(_okUrl, fromByte: 4));
      expect((e! as MediaStreamFailure).message, 'range_mismatch');
    });

    test('416 is a failure with the status, not expiry', () async {
      final http = FakeCdnHttp((_, _) => _ok(const [], status: 416));
      final e = await _error(opener(http).open(_okUrl, fromByte: 99));
      expect(e, isA<MediaStreamFailure>());
      expect((e! as MediaStreamFailure).statusCode, 416);
    });

    test('a negative fromByte is refused without a request', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok([
          [1],
        ]),
      );
      final e = await _error(opener(http).open(_okUrl, fromByte: -1));
      expect((e! as MediaStreamFailure).message, 'bad_range');
      expect(http.uris, isEmpty);
    });
  });

  group('AC3 expired URL (403 / 410) is ExpiredMediaUrl', () {
    for (final status in [403, 410]) {
      test('HTTP $status', () async {
        var cancelled = false;
        final http = FakeCdnHttp(
          (_, _) => _ok(
            [
              [1],
            ],
            status: status,
            stall: true,
            onCancel: () => cancelled = true,
          ),
        );
        final e = await _error(opener(http).open(_okUrl));
        expect(e, isA<ExpiredMediaUrl>());
        expect(cancelled, isTrue, reason: 'the error body is not downloaded');
      });
    }

    test(
      'bytes before an error stay valid; the error comes after them',
      () async {
        final http = FakeCdnHttp(
          (_, _) => _ok([
            [1, 2],
          ], errorAfter: const TransportException('socket')),
        );
        final (got, error) = await _collect(opener(http).open(_okUrl));
        expect(got, [1, 2]);
        expect((error! as MediaStreamFailure).message, 'socket');
      },
    );
  });

  group('AC3 other failures are MediaStreamFailure', () {
    for (final status in [404, 429, 500, 503, 301, 302]) {
      test('HTTP $status keeps the status code', () async {
        final http = FakeCdnHttp((_, _) => _ok(const [], status: status));
        final e = await _error(opener(http).open(_okUrl));
        expect(e, isA<MediaStreamFailure>());
        expect((e! as MediaStreamFailure).statusCode, status);
      });
    }

    test('a socket error and a timeout while connecting', () async {
      var kind = 'socket';
      final http = FakeCdnHttp((_, _) => throw TransportException(kind));
      expect(
        ((await _error(opener(http).open(_okUrl)))! as MediaStreamFailure)
            .message,
        'socket',
      );
      kind = 'timeout';
      expect(
        ((await _error(opener(http).open(_okUrl)))! as MediaStreamFailure)
            .message,
        'timeout',
      );
    });

    test('an unknown error from the client hides its text', () async {
      final http = FakeCdnHttp((_, _) => throw StateError('url $_okUrl'));
      final e = await _error(opener(http).open(_okUrl));
      expect(e.toString(), isNot(contains('ZZFAKE')));
      expect((e! as MediaStreamFailure).message, 'socket');
    });

    test('headers that never arrive time out', () async {
      final http = FakeCdnHttp((_, _) => Completer<CdnResponse>().future);
      final e = await _error(
        opener(http, response: const Duration(milliseconds: 20)).open(_okUrl),
      );
      expect((e! as MediaStreamFailure).message, 'timeout');
    });

    test('a body that stalls times out after the idle time', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok([
          [1],
        ], stall: true),
      );
      final (got, error) = await _collect(
        opener(http, idle: const Duration(milliseconds: 20)).open(_okUrl),
      );
      expect(got, [1]);
      expect((error! as MediaStreamFailure).message, 'timeout');
    });

    test('a body shorter than Content-Length is truncated', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok([
          [1, 2],
        ], length: 5),
      );
      final e = await _error(opener(http).open(_okUrl));
      expect((e! as MediaStreamFailure).message, 'truncated');
    });
  });

  group('AC3 host allowlist (the T-013 rule)', () {
    final good = [
      'https://scontent-xx1-1.cdninstagram.com/v/t51/a.jpg?sig=ZZFAKE',
      'https://video.fbcdn.net/a.mp4',
      'https://fbcdn.net/a.mp4',
      'https://cdninstagram.com/a.jpg',
      'https://SCONTENT.CDNINSTAGRAM.COM/a.jpg',
      'https://scontent.fbcdn.net:443/a.jpg',
    ];
    final bad = [
      'http://scontent.fbcdn.net/a.jpg',
      'https://example.test/a.jpg',
      'https://fbcdn.net.evil.test/a.jpg',
      'https://evilfbcdn.net/a.jpg',
      'https://notcdninstagram.com/a.jpg',
      'https://www.instagram.com/p/x/',
      'https://scontent.fbcdn.net:8443/a.jpg',
      'https://user:pw@scontent.fbcdn.net/a.jpg',
      'https://127.0.0.1/a.jpg',
      'https://[::1]/a.jpg',
      'ftp://scontent.fbcdn.net/a.jpg',
      'blob:https://www.instagram.com/abc',
      'data:image/png;base64,AAAA',
      '//scontent.fbcdn.net/a.jpg',
      'not a url',
      '',
    ];
    for (final url in good) {
      test('allowed: ${url.split('?').first}', () async {
        final http = FakeCdnHttp(
          (_, _) => _ok([
            [1],
          ]),
        );
        expect(await _bytes(opener(http).open(url)), [1]);
        expect(allowedCdnUri(url), isNotNull);
      });
    }
    for (final url in bad) {
      test('refused without a request: $url', () async {
        final http = FakeCdnHttp(
          (_, _) => _ok([
            [1],
          ]),
        );
        final e = await _error(opener(http).open(url));
        expect(e, isA<MediaStreamFailure>());
        expect((e! as MediaStreamFailure).message, 'url_rejected');
        expect(http.uris, isEmpty);
        expect(allowedCdnUri(url), isNull);
      });
    }
  });

  group('AC3 stream behaviour', () {
    test('cancelling the subscription closes the body', () async {
      var cancelled = false;
      final http = FakeCdnHttp(
        (_, _) => _ok(
          [
            [1],
          ],
          stall: true,
          onCancel: () => cancelled = true,
        ),
      );
      final first = Completer<void>();
      final sub = opener(http).open(_okUrl).listen((_) {
        if (!first.isCompleted) first.complete();
      });
      await first.future;
      await sub.cancel();
      expect(cancelled, isTrue);
    });

    test('cancelling before the headers arrive closes the late body', () async {
      var cancelled = false;
      final gate = Completer<CdnResponse>();
      final http = FakeCdnHttp((_, _) => gate.future);
      final sub = opener(http).open(_okUrl).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await sub.cancel();
      gate.complete(
        _ok(
          [
            [1],
          ],
          stall: true,
          onCancel: () => cancelled = true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cancelled, isTrue);
    });

    test('pause and resume are passed on and no byte is lost', () async {
      final http = FakeCdnHttp(
        (_, _) => _ok([
          for (var i = 0; i < 20; i++) [i],
        ]),
      );
      final got = <int>[];
      final done = Completer<void>();
      // The stream ends by itself, which closes the subscription.
      // ignore: cancel_subscriptions
      late StreamSubscription<List<int>> sub;
      sub = opener(http).open(_okUrl).listen(
        (c) {
          got.addAll(c);
          if (got.length == 5) {
            sub.pause();
            Future<void>.delayed(const Duration(milliseconds: 10), sub.resume);
          }
        },
        onDone: done.complete,
      );
      await done.future;
      expect(got, List.generate(20, (i) => i));
    });
  });

  group('no URL in any log, and nothing governed (ADR-0009)', () {
    test(
      'ok, expired, failed and rejected leave no URL, host or signature',
      () async {
        final cases = <FutureOr<CdnResponse> Function()>[
          () => _ok([
            [1],
          ]),
          () => _ok(const [], status: 403),
          () => _ok(const [], status: 500),
          () => throw StateError('boom $_okUrl'),
        ];
        for (final make in cases) {
          await _error(opener(FakeCdnHttp((_, _) => make())).open(_okUrl));
        }
        await _error(
          opener(
            FakeCdnHttp(
              (_, _) => _ok([
                [1],
              ]),
            ),
          ).open('https://evil.test/ZZFAKE'),
        );
        final text = logText(log);
        expect(text, contains('op=openMedia outcome=ok'));
        expect(text, contains('outcome=expired status=403'));
        expect(text, contains('outcome=url_rejected'));
        for (final leak in [
          'ZZFAKE',
          'fbcdn',
          'evil.test',
          'https',
          'http:',
          'sig=',
        ]) {
          expect(text, isNot(contains(leak)), reason: leak);
        }
      },
    );

    test('the media opener has no governor: constructing it needs none and '
        'a download makes no governed call', () async {
      // The structural half: CdnMediaOpener's constructor takes an HTTP
      // client and a log only. The behavioural half is the assemble test.
      final http = FakeCdnHttp(
        (_, _) => _ok([
          [1],
        ]),
      );
      expect(await _bytes(opener(http).open(_okUrl)), [1]);
    });
  });
}
