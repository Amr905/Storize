import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/update/update.dart';

/// Mock adapter: no network. Records the last request for assertions.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    last = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

final String _sha = 'ab' * 32; // 64 hex characters

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, Object?> _release({
  Object? tag = 'v0.2.0',
  Object? html = 'https://github.com/Amr905/Storize/releases/tag/v0.2.0',
  Object? body = '',
}) => {
  'tag_name': tag,
  'html_url': html,
  'body': body,
};

UpdateChecker _checkerWith(_FakeAdapter adapter, {Duration? timeout}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return UpdateChecker(
    dio: dio,
    timeout: timeout ?? const Duration(seconds: 10),
  );
}

_FakeAdapter _serving(Object body, {int status = 200}) =>
    _FakeAdapter((_) async => _json(body, status: status));

void main() {
  group('SemanticVersion.tryParse', () {
    test('accepts plain, v-prefixed, pre-release and build forms', () {
      expect(SemanticVersion.tryParse('1.2.3')?.toString(), '1.2.3');
      expect(SemanticVersion.tryParse('v1.2.3')?.toString(), '1.2.3');
      expect(SemanticVersion.tryParse('V1.2.3')?.toString(), '1.2.3');
      expect(SemanticVersion.tryParse('  v1.2.3  ')?.toString(), '1.2.3');
      expect(
        SemanticVersion.tryParse('1.2.3-beta.2')?.toString(),
        '1.2.3-beta.2',
      );
      expect(SemanticVersion.tryParse('1.2.3+build.7')?.toString(), '1.2.3');
    });

    for (final bad in [
      '',
      'v',
      '1',
      '1.2',
      '1.2.3.4',
      'a.b.c',
      '1.2.x',
      '1.2.-3',
      '-1.2.3',
      '1.2.3-',
      '1.2.3-be..ta',
      '1.2.3-beta!',
      '1.2.3+',
      'latest',
      '1.2.3 4',
    ]) {
      test('rejects "$bad"', () {
        expect(SemanticVersion.tryParse(bad), isNull);
      });
    }
  });

  group('SemanticVersion comparison table', () {
    // (left, right, expected sign of left.compareTo(right))
    const table = <(String, String, int)>[
      ('1.2.3', '1.2.3', 0),
      ('1.2.3', '1.2.4', -1),
      ('1.2.4', '1.2.3', 1),
      ('1.10.0', '1.9.9', 1),
      ('2.0.0', '1.99.99', 1),
      ('0.1.0', '0.1.10', -1),
      ('v1.2.3', '1.2.3', 0),
      ('1.2.3+build.7', '1.2.3', 0),
      ('1.2.3+a', '1.2.3+b', 0),
      ('1.2.3-beta', '1.2.3', -1),
      ('1.2.3', '1.2.3-beta', 1),
      ('1.2.3-beta+exp', '1.2.3-beta', 0),
      ('1.2.3-alpha', '1.2.3-beta', -1),
      ('1.2.3-beta.2', '1.2.3-beta.11', -1),
      ('1.2.3-1', '1.2.3-alpha', -1),
      ('1.2.3-beta', '1.2.3-beta.1', -1),
      ('1.2.4-beta', '1.2.3', 1),
    ];

    for (final (left, right, expected) in table) {
      test('$left vs $right -> $expected', () {
        final a = SemanticVersion.tryParse(left)!;
        final b = SemanticVersion.tryParse(right)!;
        expect(a.compareTo(b).sign, expected);
        expect(b.compareTo(a).sign, -expected);
      });
    }
  });

  group('UpdateChecker request', () {
    test(
      'calls the releases/latest endpoint with the expected headers',
      () async {
        final adapter = _serving(_release());
        await _checkerWith(adapter).checkForUpdate(currentVersion: '0.1.0');

        final req = adapter.last!;
        expect(req.uri.toString(), latestReleaseUrl);
        expect(
          req.uri.toString(),
          'https://api.github.com/repos/Amr905/Storize/releases/latest',
        );
        expect(req.method, 'GET');
        expect(req.headers['Accept'], 'application/vnd.github+json');
        expect(req.receiveTimeout, const Duration(seconds: 10));
      },
    );
  });

  group('UpdateChecker outcomes', () {
    test('newer available -> UpdateAvailable with url and sha', () async {
      final adapter = _serving(_release(body: 'sha256: $_sha'));
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');

      expect(state, isA<UpdateAvailable>());
      final offer = state as UpdateAvailable;
      expect(offer.version, '0.2.0');
      expect(
        offer.url,
        Uri.parse('https://github.com/Amr905/Storize/releases/tag/v0.2.0'),
      );
      expect(offer.sha256, _sha);
    });

    test('same version -> none', () async {
      final adapter = _serving(_release(tag: 'v0.1.0'));
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, UpdateState.none);
    });

    test('older remote -> none', () async {
      final adapter = _serving(_release(tag: 'v0.0.9'));
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, UpdateState.none);
    });

    test(
      'pre-release current is offered the release (0.2.0-beta -> 0.2.0)',
      () async {
        final adapter = _serving(_release());
        final state = await _checkerWith(adapter)
            .checkForUpdate(currentVersion: '0.2.0-beta');
        expect(state, isA<UpdateAvailable>());
      },
    );

    test(
      'remote pre-release is not newer than the release it precedes',
      () async {
        final adapter = _serving(_release(tag: 'v0.2.0-beta'));
        final state = await _checkerWith(adapter)
            .checkForUpdate(currentVersion: '0.2.0');
        expect(state, UpdateState.none);
      },
    );

    test('current below min-supported -> UpdateRequired', () async {
      final adapter = _serving(
        _release(tag: 'v0.3.0', body: 'min-supported: 0.2.0'),
      );
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, isA<UpdateRequired>());
      expect((state as UpdateRequired).version, '0.3.0');
    });

    test(
      'current equal to min-supported -> UpdateAvailable, not required',
      () async {
        final adapter = _serving(
          _release(tag: 'v0.3.0', body: 'min-supported: 0.2.0'),
        );
        final state = await _checkerWith(adapter)
            .checkForUpdate(currentVersion: '0.2.0');
        expect(state, isA<UpdateAvailable>());
      },
    );

    test('current below min-supported, remote not newer -> none', () async {
      // Remote 0.1.0 is not newer than current 0.1.0, so nothing to install.
      final adapter = _serving(
        _release(tag: 'v0.1.0', body: 'min-supported: 0.5.0'),
      );
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, UpdateState.none);
    });

    test(
      'min-supported above current, remote newer -> UpdateRequired',
      () async {
        final adapter = _serving(
          _release(tag: 'v0.1.0', body: 'min-supported: 0.5.0'),
        );
        final state = await _checkerWith(adapter)
            .checkForUpdate(currentVersion: '0.0.1');
        expect(state, isA<UpdateRequired>());
      },
    );

    test('malformed min-supported is ignored -> UpdateAvailable', () async {
      final adapter = _serving(
        _release(body: 'min-supported: two'),
      );
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, isA<UpdateAvailable>());
    });

    test('invalid current version -> none without a request', () async {
      final adapter = _serving(_release());
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: 'not-a-version');
      expect(state, UpdateState.none);
      expect(adapter.last, isNull);
    });
  });

  group('UpdateChecker body parsing', () {
    test('CRLF line endings are parsed', () async {
      final adapter = _serving(
        _release(
          tag: 'v0.3.0',
          body: 'Notes\r\nmin-supported: 0.2.0\r\nsha256: $_sha\r\n',
        ),
      );
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, isA<UpdateRequired>());
      expect((state as UpdateRequired).sha256, _sha);
    });

    test('extra spaces and mixed-case keys are tolerated', () async {
      final upper = _sha.toUpperCase();
      final adapter = _serving(
        _release(
          tag: 'v0.3.0',
          body: '   MIN-SUPPORTED:    0.2.0   \n\t  Sha256 :  $upper  \n',
        ),
      );
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, isA<UpdateRequired>());
      // Sha is normalised to lowercase.
      expect((state as UpdateRequired).sha256, _sha);
    });

    test('missing body gives available with null sha', () async {
      final adapter = _serving(_release(body: null));
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, isA<UpdateAvailable>());
      final offer = state as UpdateAvailable;
      expect(offer.version, '0.2.0');
      expect(offer.sha256, isNull);
    });

    test('empty body gives available with null sha', () async {
      final adapter = _serving(_release());
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect((state as UpdateAvailable).sha256, isNull);
    });

    test('sha line with 63 hex characters keeps state with null sha', () async {
      final adapter = _serving(
        _release(
          body: 'sha256: ${'ab' * 31}a',
        ),
      );
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect(state, isA<UpdateAvailable>());
      expect((state as UpdateAvailable).sha256, isNull);
    });

    test(
      'sha line with non-hex characters keeps state with null sha',
      () async {
        final adapter = _serving(
          _release(
            body: 'sha256: ${'zz' * 32}',
          ),
        );
        final state = await _checkerWith(adapter)
            .checkForUpdate(currentVersion: '0.1.0');
        expect((state as UpdateAvailable).sha256, isNull);
      },
    );

    test('a valid sha followed by trailing text is still accepted', () async {
      final adapter = _serving(
        _release(
          body: 'sha256: $_sha  (storize.apk)',
        ),
      );
      final state = await _checkerWith(adapter)
          .checkForUpdate(currentVersion: '0.1.0');
      expect((state as UpdateAvailable).sha256, _sha);
    });
  });

  group('UpdateChecker silent on errors', () {
    Future<UpdateState> run(_FakeAdapter adapter, {Duration? timeout}) =>
        _checkerWith(
          adapter,
          timeout: timeout,
        ).checkForUpdate(currentVersion: '0.1.0');

    test('connection error -> none', () async {
      final adapter = _FakeAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(await run(adapter), UpdateState.none);
    });

    test('timeout (never responds) -> none', () async {
      final adapter = _FakeAdapter(
        (_) => Completer<ResponseBody>().future,
      );
      expect(
        await run(adapter, timeout: const Duration(milliseconds: 20)),
        UpdateState.none,
      );
    });

    test('404 -> none', () async {
      final adapter = _serving({'message': 'Not Found'}, status: 404);
      expect(await run(adapter), UpdateState.none);
    });

    test('403 (rate limit) -> none', () async {
      final adapter = _serving({
        'message': 'API rate limit exceeded',
      }, status: 403);
      expect(await run(adapter), UpdateState.none);
    });

    test('429 -> none', () async {
      final adapter = _serving({'message': 'Too Many Requests'}, status: 429);
      expect(await run(adapter), UpdateState.none);
    });

    test('500 -> none', () async {
      final adapter = _serving({'message': 'boom'}, status: 500);
      expect(await run(adapter), UpdateState.none);
    });

    test('malformed JSON -> none', () async {
      final adapter = _FakeAdapter(
        (_) async => ResponseBody.fromString(
          '{not json',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      expect(await run(adapter), UpdateState.none);
    });

    test('JSON that is not an object -> none', () async {
      final adapter = _FakeAdapter(
        (_) async => ResponseBody.fromString(
          '["v0.2.0"]',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      expect(await run(adapter), UpdateState.none);
    });

    test('empty body -> none', () async {
      final adapter = _FakeAdapter(
        (_) async => ResponseBody.fromString(
          '',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      expect(await run(adapter), UpdateState.none);
    });

    test('malformed tag -> none', () async {
      final adapter = _serving(_release(tag: 'latest'));
      expect(await run(adapter), UpdateState.none);
    });

    test('missing tag_name -> none', () async {
      final adapter = _serving({'html_url': 'https://github.com/x'});
      expect(await run(adapter), UpdateState.none);
    });

    test('missing html_url -> none', () async {
      final adapter = _serving({'tag_name': 'v0.2.0'});
      expect(await run(adapter), UpdateState.none);
    });

    test('non-https html_url -> none', () async {
      final adapter = _serving(_release(html: 'http://example.com/release'));
      expect(await run(adapter), UpdateState.none);
    });

    test('non-string tag_name -> none', () async {
      final adapter = _serving(_release(tag: 2));
      expect(await run(adapter), UpdateState.none);
    });
  });

  group('UpdateState equality', () {
    test('none is a canonical constant', () {
      expect(identical(UpdateState.none, UpdateState.none), isTrue);
      expect(UpdateState.none, isA<UpdateNone>());
    });

    test('available and required are distinct subtypes', () {
      final url = Uri.parse('https://example.com/r');
      final available = UpdateAvailable(version: '1.0.0', url: url);
      final required = UpdateRequired(version: '1.0.0', url: url);
      expect(available, isA<UpdateAvailable>());
      expect(available, isNot(isA<UpdateRequired>()));
      expect(required, isA<UpdateRequired>());
      expect(required, isNot(isA<UpdateAvailable>()));
    });
  });
}
