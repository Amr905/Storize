import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/security/security.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

// Obviously fake values. Every test scans for them in messages.
const String _fakeSessionId = 'FAKE-sessionid-VALUE-0001';
const String _fakeUserId = 'FAKE-dsuserid-VALUE-0002';
const String _fakeCsrf = 'FAKE-csrftoken-VALUE-0003';
const List<String> _secrets = [_fakeSessionId, _fakeUserId, _fakeCsrf];

SessionBlob _blob({
  Map<String, String>? cookies,
  DateTime? capturedAt,
  String ua = 'TestAgent/1.0',
}) => SessionBlob(
  cookies:
      cookies ??
      {
        'sessionid': _fakeSessionId,
        'ds_user_id': _fakeUserId,
        'csrftoken': _fakeCsrf,
      },
  userAgent: ua,
  capturedAt: capturedAt ?? DateTime.utc(2026, 11, 19, 10, 30, 15, 123),
);

/// A hand-written backend (the plugin's mock platform cannot throw).
class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;
  Exception? readError;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final error = readError;
    if (error != null) throw error;
    return data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

void _expectNoSecret(String text, String where) {
  for (final s in _secrets) {
    expect(text.contains(s), isFalse, reason: 'secret leaked in $where');
  }
}

void main() {
  late _FakeStorage backend;
  late List<(int, String)> reports;
  late SecureStorageSessionStore store;

  setUp(() {
    backend = _FakeStorage();
    reports = [];
    store = SecureStorageSessionStore(
      backend,
      onUnreadable: (id, reason) => reports.add((id, reason)),
    );
  });

  group('SecureStorageSessionStore', () {
    test('AC1: round-trips cookies, UA and capturedAt', () async {
      final blob = _blob();
      await store.save(1, blob);
      final loaded = await store.load(1);
      expect(loaded, blob);
      expect(loaded!.cookies['csrftoken'], _fakeCsrf);
      expect(reports, isEmpty);
    });

    test('stores a versioned envelope under storize.session.<id>', () async {
      await store.save(7, _blob());
      expect(backend.data.keys, ['storize.session.7']);
      final json = jsonDecode(
        backend.data['storize.session.7']!,
      ) as Map<String, Object?>;
      expect(json['v'], 1);
      expect(json['userAgent'], 'TestAgent/1.0');
      expect(json['capturedAt'], isA<int>());
      expect((json['cookies']! as Map)['sessionid'], _fakeSessionId);
    });

    test('capturedAt is stored as UTC epoch milliseconds', () async {
      final at = DateTime.utc(2026, 11, 19, 10, 30, 15, 123, 456);
      await store.save(1, _blob(capturedAt: at));
      final json = jsonDecode(
        backend.data['storize.session.1']!,
      ) as Map<String, Object?>;
      expect(json['capturedAt'], 1795084215123);
      final loaded = (await store.load(1))!;
      expect(loaded.capturedAt.isUtc, isTrue);
      expect(loaded.capturedAt, DateTime.utc(2026, 11, 19, 10, 30, 15, 123));
    });

    test('a local-time capturedAt is stored as the same instant', () async {
      final local = DateTime.utc(2026, 11, 19, 8).toLocal();
      await store.save(1, _blob(capturedAt: local));
      expect((await store.load(1))!.capturedAt, DateTime.utc(2026, 11, 19, 8));
    });

    test('keeps accounts apart', () async {
      final a = _blob();
      final b = _blob(
        cookies: {'sessionid': 'FAKE-other-1', 'ds_user_id': 'FAKE-other-2'},
        ua: 'Other/2',
      );
      await store.save(1, a);
      await store.save(2, b);
      expect(await store.load(1), a);
      expect(await store.load(2), b);
      await store.clear(1);
      expect(await store.load(1), isNull);
      expect(await store.load(2), b);
      expect(reports, isEmpty);
    });

    test('save replaces the old session', () async {
      await store.save(1, _blob());
      final newer = _blob(ua: 'New/3');
      await store.save(1, newer);
      expect(await store.load(1), newer);
    });

    test('a missing key returns null without a report', () async {
      expect(await store.load(99), isNull);
      expect(reports, isEmpty);
    });

    test('clear is idempotent', () async {
      await store.save(1, _blob());
      await store.clear(1);
      await store.clear(1);
      await store.clear(42);
      expect(await store.load(1), isNull);
      expect(backend.data, isEmpty);
    });

    group('AC2: unreadable data returns null and reports', () {
      Future<void> expectUnreadable(String raw, String reason) async {
        backend.data['storize.session.1'] = raw;
        expect(await store.load(1), isNull);
        expect(reports, [(1, reason)]);
      }

      test('corrupted JSON', () async {
        await expectUnreadable(
          '{"v":1,"cookies":{"sessionid":"$_fakeSessionId',
          SessionUnreadableReason.corruptJson,
        );
      });

      test('wrong version', () async {
        await expectUnreadable(
          jsonEncode({
            'v': 2,
            'cookies': {'sessionid': _fakeSessionId, 'ds_user_id': _fakeUserId},
            'userAgent': 'x',
            'capturedAt': 1,
          }),
          SessionUnreadableReason.unknownVersion,
        );
      });

      test('missing version', () async {
        await expectUnreadable(
          jsonEncode({'cookies': <String, String>{}}),
          SessionUnreadableReason.unknownVersion,
        );
      });

      test('not a JSON object', () async {
        await expectUnreadable('[1,2]', SessionUnreadableReason.invalidShape);
      });

      test('wrong field types', () async {
        await expectUnreadable(
          jsonEncode({
            'v': 1,
            'cookies': {'sessionid': 5, 'ds_user_id': _fakeUserId},
            'userAgent': 'x',
            'capturedAt': 1,
          }),
          SessionUnreadableReason.invalidShape,
        );
      });

      test('stored cookies lack a required cookie', () async {
        await expectUnreadable(
          jsonEncode({
            'v': 1,
            'cookies': {'sessionid': _fakeSessionId},
            'userAgent': 'x',
            'capturedAt': 1,
          }),
          SessionUnreadableReason.invalidShape,
        );
      });

      test('a platform exception on read', () async {
        backend.readError = PlatformException(
          code: 'KeyPermanentlyInvalidated',
          message: 'details $_fakeSessionId',
        );
        expect(await store.load(3), isNull);
        expect(reports, [(3, SessionUnreadableReason.platformError)]);
      });

      test('a non-platform exception on read', () async {
        backend.readError = const FormatException('boom');
        expect(await store.load(3), isNull);
        expect(reports, [(3, SessionUnreadableReason.platformError)]);
      });

      test('no callback is fine', () async {
        final quiet = SecureStorageSessionStore(backend);
        backend.data['storize.session.1'] = 'not json';
        expect(await quiet.load(1), isNull);
      });

      test('a throwing callback never makes load throw', () async {
        final noisy = SecureStorageSessionStore(
          backend,
          onUnreadable: (_, _) => throw StateError('callback failed'),
        );
        backend.data['storize.session.1'] = 'not json';
        expect(await noisy.load(1), isNull);
      });

      test('markLoggedOutOnUnreadable marks the account LOGGED_OUT', () async {
        final accounts = FakeAccountRepo();
        final account = await accounts.upsert(
          LoginAccount(
            id: LoginAccount.unsavedId,
            platform: PlatformId.instagram,
            remoteUserId: 'fake-remote-1',
            username: 'fake_user',
            status: AccountStatus.active,
            connectedAt: DateTime.utc(2026, 11, 19),
          ),
        );
        final wired = SecureStorageSessionStore(
          backend,
          onUnreadable: markLoggedOutOnUnreadable(accounts),
        );
        backend.data['storize.session.${account.id}'] = '%%%';
        expect(await wired.load(account.id), isNull);
        final after = (await accounts.getActive())!;
        expect(after.status, AccountStatus.loggedOut);
        expect(after.statusReason, SessionUnreadableReason.corruptJson);
      });

      test('markLoggedOutOnUnreadable survives a missing account', () async {
        final cb = markLoggedOutOnUnreadable(FakeAccountRepo());
        await cb(404, SessionUnreadableReason.platformError);
      });
    });

    group('save validation', () {
      test('rejects a missing sessionid without leaking values', () async {
        await expectLater(
          store.save(1, _blob(cookies: {'ds_user_id': _fakeUserId})),
          throwsA(
            isA<ArgumentError>().having(
              (e) {
                final text = e.toString();
                _expectNoSecret(text, 'ArgumentError');
                return text;
              },
              'message',
              allOf(contains('sessionid'), isNot(contains('ds_user_id'))),
            ),
          ),
        );
        expect(backend.data, isEmpty);
      });

      test('rejects an empty ds_user_id and names both when missing', () async {
        await expectLater(
          store.save(
            1,
            _blob(cookies: {'sessionid': _fakeSessionId, 'ds_user_id': ''}),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('ds_user_id'), isNot(contains(_fakeSessionId))),
            ),
          ),
        );
        await expectLater(
          store.save(1, _blob(cookies: {'csrftoken': _fakeCsrf})),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('sessionid'),
                contains('ds_user_id'),
                isNot(contains(_fakeCsrf)),
              ),
            ),
          ),
        );
        expect(backend.data, isEmpty);
      });
    });

    test('AC3: no text or callback argument has a secret', () async {
      final texts = <String>[];
      final callbackArgs = <Object?>[];
      final scanning = SecureStorageSessionStore(
        backend,
        onUnreadable: (id, reason) => callbackArgs
          ..add(id)
          ..add(reason),
      );
      await scanning.save(1, _blob());
      texts
        ..add(scanning.toString())
        ..add(_blob().toString());

      // Corrupt data that contains secrets, read failures that quote them.
      backend.data['storize.session.1'] =
          '{"v":1,"cookies":{"sessionid":"$_fakeSessionId",'
          '"ds_user_id":"$_fakeUserId';
      expect(await scanning.load(1), isNull);
      backend.data['storize.session.1'] = jsonEncode({
        'v': 9,
        'cookies': {'sessionid': _fakeSessionId, 'ds_user_id': _fakeUserId},
      });
      expect(await scanning.load(1), isNull);
      backend.readError = PlatformException(
        code: 'x',
        message: 'quoting $_fakeSessionId $_fakeUserId',
      );
      expect(await scanning.load(1), isNull);

      for (final cookies in <Map<String, String>>[
        {'ds_user_id': _fakeUserId, 'csrftoken': _fakeCsrf},
        {'sessionid': _fakeSessionId, 'csrftoken': _fakeCsrf},
        {'sessionid': '', 'ds_user_id': _fakeUserId},
      ]) {
        try {
          await scanning.save(1, _blob(cookies: cookies));
          fail('save should have thrown');
        } on Object catch (e) {
          if (e is! ArgumentError) rethrow;
          texts
            ..add(e.toString())
            ..add('${e.message}');
        }
      }

      expect(callbackArgs, isNotEmpty);
      for (final t in texts) {
        _expectNoSecret(t, 'text: $t');
      }
      for (final a in callbackArgs) {
        expect(a is int || a is String, isTrue);
        _expectNoSecret('$a', 'callback argument');
      }
    });

    test(
      'AC4: a second store over the same backend sees the session',
      () async {
        // Models the workmanager isolate: its own store instance, same Keystore
        // backed data. Real isolates cannot run in a unit test.
        await store.save(1, _blob());
        final other = SecureStorageSessionStore(backend);
        expect(await other.load(1), _blob());
      },
    );

    test('AC5: works over the plugin mock platform', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final real = SecureStorageSessionStore(
        SecureStorageSessionStore.defaultStorage(),
        onUnreadable: (id, reason) => reports.add((id, reason)),
      );
      await real.save(5, _blob());
      expect(await real.load(5), _blob());
      await real.clear(5);
      await real.clear(5);
      expect(await real.load(5), isNull);

      FlutterSecureStorage.setMockInitialValues({
        'storize.session.5': 'garbage',
      });
      expect(await real.load(5), isNull);
      expect(reports, [(5, SessionUnreadableReason.corruptJson)]);
    });
  });

  group('parity with FakeSessionStore', () {
    final factories = <String, SessionStore Function()>{
      'SecureStorageSessionStore': () =>
          SecureStorageSessionStore(_FakeStorage()),
      'FakeSessionStore': FakeSessionStore.new,
    };
    for (final entry in factories.entries) {
      group(entry.key, () {
        late SessionStore s;
        setUp(() => s = entry.value());

        test('round-trip', () async {
          final blob = _blob();
          await s.save(1, blob);
          expect(await s.load(1), blob);
        });

        test('isolation between accounts', () async {
          await s.save(1, _blob());
          expect(await s.load(2), isNull);
          await s.save(2, _blob(ua: 'B/1'));
          await s.clear(1);
          expect((await s.load(2))!.userAgent, 'B/1');
        });

        test('clear is idempotent and load of missing is null', () async {
          await s.clear(1);
          await s.save(1, _blob());
          await s.clear(1);
          await s.clear(1);
          expect(await s.load(1), isNull);
        });

        test('millisecond UTC capturedAt survives', () async {
          final at = DateTime.utc(2026, 1, 2, 3, 4, 5, 678);
          await s.save(1, _blob(capturedAt: at));
          expect((await s.load(1))!.capturedAt, at);
        });
      });
    }
  });
}
