// Test-only style relaxations: fixtures use long fake URLs and literals.
// ignore_for_file: lines_longer_than_80_chars, unnecessary_lambdas
// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

// Independent QA checks for T-003. All secrets below are fake but shaped like
// real Instagram values.
const _fakeSessionId =
    '48291037584%3AqZr7TfK2mLpX9aVb%3A17%3AAYc3dE5fGhIjKlMnOpQrStUvWxYz0123456789abcd';
const _fakeCsrf = 'Xk3P9mQ2rT7vB1nL5cD8fG4hJ6sA0wEz';
const _fakeDsUser = '48291037584';
const _fakeSignedUrl =
    'https://scontent-cai1-1.cdninstagram.com/v/t51.2885-15/123_n.jpg'
    '?stp=dst-jpg_e35&_nc_ht=scontent-cai1-1.cdninstagram.com'
    '&oh=00_AfDsIgNeDhAsH9x8y7z&oe=6740ABCD';

void main() {
  group('QA: redaction with realistic secrets', () {
    final blob = SessionBlob(
      cookies: {
        'sessionid': _fakeSessionId,
        'csrftoken': _fakeCsrf,
        'ds_user_id': _fakeDsUser,
      },
      userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8)',
      capturedAt: DateTime.utc(2026, 11, 19),
    );

    test(
      'SessionBlob.toString, interpolation and Ok/Err wrappers leak no values',
      () {
        final renderings = [
          blob.toString(),
          '$blob',
          Ok<SessionBlob>(blob).toString(),
          [blob].toString(),
          {'k': blob}.toString(),
        ];
        for (final text in renderings) {
          expect(text, isNot(contains(_fakeSessionId)));
          expect(text, isNot(contains('qZr7TfK2')));
          expect(text, isNot(contains(_fakeCsrf)));
          expect(text, isNot(contains(_fakeDsUser)));
          expect(text, contains('sessionid'));
        }
      },
    );

    test('RemoteMedia.toString leaks no URL parts, even inside containers', () {
      const m = RemoteMedia(
        index: 0,
        type: MediaType.photo,
        url: _fakeSignedUrl,
        width: 1080,
        height: 1920,
      );
      final renderings = [
        m.toString(),
        '$m',
        Ok<RemoteMedia>(m).toString(),
        [m].toString(),
      ];
      for (final text in renderings) {
        expect(text, isNot(contains('oh=')));
        expect(text, isNot(contains('oe=')));
        expect(text, isNot(contains('cdninstagram')));
        expect(text, isNot(contains('AfDsIgNeDhAsH9')));
      }
    });

    test('RemoteContent.toString does not reach slide URLs', () {
      final c = RemoteContent(
        remoteId: '1',
        kind: ContentKind.post,
        postedAt: DateTime.utc(2026),
        caption: 'secret caption',
        slides: const [
          RemoteMedia(
            index: 0,
            type: MediaType.photo,
            url: _fakeSignedUrl,
            width: 1,
            height: 1,
          ),
        ],
      );
      expect(c.toString(), isNot(contains('cdninstagram')));
      expect(c.toString(), isNot(contains('secret caption')));
    });

    test('RemoteUser.toString omits the avatar URL', () {
      const u = RemoteUser(
        remoteUserId: '1',
        username: 'nour_k',
        followedByViewer: false,
        blockedByViewer: false,
        avatarUrl: _fakeSignedUrl,
      );
      expect(u.toString(), isNot(contains('cdninstagram')));
    });
  });

  group('QA: immutability (every mutator throws)', () {
    const media = RemoteMedia(
      index: 0,
      type: MediaType.photo,
      url: 'https://x.test/a.jpg',
      width: 1,
      height: 1,
    );

    test('RemoteContent.slides rejects add, remove, clear, set, sort', () {
      final c = RemoteContent(
        remoteId: '1',
        kind: ContentKind.post,
        postedAt: DateTime.utc(2026),
        slides: [media, media],
      );
      expect(() => c.slides.add(media), throwsUnsupportedError);
      expect(() => c.slides.removeLast(), throwsUnsupportedError);
      expect(() => c.slides.clear(), throwsUnsupportedError);
      expect(() => c.slides[0] = media, throwsUnsupportedError);
      expect(() => c.slides.sort((a, b) => 0), throwsUnsupportedError);
    });

    test('RemoteContent.extras rejects mutation at every nesting level', () {
      final c = RemoteContent(
        remoteId: '1',
        kind: ContentKind.story,
        postedAt: DateTime.utc(2026),
        slides: const [],
        extras: {
          'mentions': <Object?>['a', 'b'],
          'location': <String, Object?>{'name': 'Cairo'},
          'deep': <Object?>[
            <String, Object?>{
              'inner': <Object?>[1],
            },
          ],
        },
      );
      expect(() => c.extras['new'] = 1, throwsUnsupportedError);
      expect(() => c.extras.remove('mentions'), throwsUnsupportedError);
      expect(() => c.extras.clear(), throwsUnsupportedError);
      expect(
        () => (c.extras['mentions']! as List<Object?>).add('c'),
        throwsUnsupportedError,
      );
      expect(
        () => (c.extras['location']! as Map<Object?, Object?>)['x'] = 1,
        throwsUnsupportedError,
      );
      final deep =
          (c.extras['deep']! as List<Object?>)[0]! as Map<Object?, Object?>;
      expect(() => deep['z'] = 1, throwsUnsupportedError);
      expect(
        () => (deep['inner']! as List<Object?>).add(2),
        throwsUnsupportedError,
      );
    });

    test('mutating the caller-supplied nested input after construction has no effect', () {
      final inner = <Object?>['a'];
      final extras = <String, Object?>{'m': inner};
      final c = RemoteContent(
        remoteId: '1',
        kind: ContentKind.story,
        postedAt: DateTime.utc(2026),
        slides: const [],
        extras: extras,
      );
      inner.add('b');
      expect(c.extras['m'], ['a']);
    });

    test('SessionBlob.cookies rejects add, overwrite, remove, clear', () {
      final b = SessionBlob(
        cookies: {'sessionid': 'v'},
        userAgent: 'ua',
        capturedAt: DateTime.utc(2026),
      );
      expect(() => b.cookies['n'] = 'v', throwsUnsupportedError);
      expect(() => b.cookies['sessionid'] = 'other', throwsUnsupportedError);
      expect(() => b.cookies.remove('sessionid'), throwsUnsupportedError);
      expect(() => b.cookies.clear(), throwsUnsupportedError);
    });
  });

  group('QA: known finding F-1', () {
    test(
      'nested extras maps can be read as Map<String, Object?>',
      () {
        final c = RemoteContent(
          remoteId: '1',
          kind: ContentKind.story,
          postedAt: DateTime.utc(2026),
          slides: const [],
          extras: {
            'location': <String, Object?>{'name': 'Cairo'},
          },
        );
        // Currently throws a TypeError: the nested map is re-typed as
        // Map<Object?, Object?> by deepUnmodifiable.
        expect(c.extras['location']! as Map<String, Object?>, isNotNull);
      },
    );
  });

  group('QA: exhaustiveness without default', () {
    // If a subclass were added or removed, this file would stop compiling
    // (non_exhaustive_switch_expression is an error in Dart 3).
    String name(Failure f) => switch (f) {
      NetworkFailure() => 'NetworkFailure',
      RateLimited() => 'RateLimited',
      SessionInvalid() => 'SessionInvalid',
      AccountRestricted() => 'AccountRestricted',
      TargetNotFound() => 'TargetNotFound',
      TargetNotVisible() => 'TargetNotVisible',
      SchemaChanged() => 'SchemaChanged',
      UnknownFailure() => 'UnknownFailure',
    };

    String res(Result<int> r) => switch (r) {
      Ok<int>() => 'ok',
      Err<int>() => 'err',
    };

    test('all 8 failures and both result cases are reachable', () {
      const all = <Failure>[
        NetworkFailure(),
        RateLimited(Duration(seconds: 1)),
        SessionInvalid(SessionReason.challenge),
        AccountRestricted(),
        TargetNotFound(),
        TargetNotVisible(),
        SchemaChanged('w'),
        UnknownFailure(500, 'm'),
      ];
      expect(all.map(name).toSet(), hasLength(8));
      for (final f in all) {
        expect(f.runtimeType.toString(), name(f));
      }
      expect(res(const Ok(1)), 'ok');
      expect(res(const Err(NetworkFailure())), 'err');
    });
  });
}
