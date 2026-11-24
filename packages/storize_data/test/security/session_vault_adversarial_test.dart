// Test-only file: throwing non-Exception values and terse style are deliberate.
// ignore_for_file: only_throw_errors, avoid_types_on_closure_parameters, prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_catching_errors, cascade_invocations, omit_local_variable_types, lines_longer_than_80_chars, unawaited_futures
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/security/security.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

// QA adversarial tests for T-008. Distinctive fake secrets only.
const String _s1 = 'ZZFAKE_SESSION_9f8e7d6c5b4a_ONE';
const String _s2 = 'ZZFAKE_DSUSER_1a2b3c4d5e6f_TWO';
const String _s3 = 'ZZFAKE_CSRF_0p9o8i7u6y5t_THREE';
const List<String> _secrets = [_s1, _s2, _s3];

SessionBlob _blob({String s1 = _s1, DateTime? at}) => SessionBlob(
  cookies: {'sessionid': s1, 'ds_user_id': _s2, 'csrftoken': _s3},
  userAgent: 'QA/1.0',
  capturedAt: at ?? DateTime.utc(2026, 11, 19, 12),
);

/// Backend with optional latency, to force interleavings.
class _Backend extends FlutterSecureStorage {
  final Map<String, String> data = {};
  Object? readError;
  Object? writeError;
  Duration latency = Duration.zero;
  final List<String> log = [];

  Future<void> _wait() => Future<void>.delayed(latency);

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
    await _wait();
    if (readError != null) throw readError!;
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
    await _wait();
    if (writeError != null) throw writeError!;
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
    await _wait();
    data.remove(key);
  }
}

void _noSecret(Object? o, String where) {
  final text = '$o';
  for (final s in _secrets) {
    expect(text.contains(s), isFalse, reason: 'LEAK in $where: $text');
  }
}

String _env(Object? v, {Object? at = 1000, Object? cookies}) => jsonEncode({
  'v': v,
  'cookies': cookies ?? {'sessionid': _s1, 'ds_user_id': _s2},
  'userAgent': 'QA/1.0',
  'capturedAt': at,
});

void main() {
  late _Backend backend;
  late List<(int, String)> reports;
  late SecureStorageSessionStore store;
  late List<String> printed;

  setUp(() {
    backend = _Backend();
    reports = [];
    printed = [];
    store = SecureStorageSessionStore(
      backend,
      onUnreadable: (id, r) => reports.add((id, r)),
    );
  });

  /// Runs [body] capturing print, debugPrint and developer.log-adjacent text.
  Future<T> capture<T>(Future<T> Function() body) async {
    final old = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => printed.add('dbg:$m');
    try {
      return await runZoned(
        body,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
    } finally {
      debugPrint = old;
    }
  }

  group('leak hunt', () {
    final cases = <String, void Function()>{
      'corrupt JSON containing secret': () =>
          backend.data['storize.session.1'] =
              '{"v":1,"cookies":{"sessionid":"$_s1","ds_user_id":"$_s2',
      'wrong version containing secret': () =>
          backend.data['storize.session.1'] = _env(2),
      'v as string': () => backend.data['storize.session.1'] = _env('1'),
      'secret as non-string cookie value': () =>
          backend.data['storize.session.1'] = _env(
            1,
            cookies: {'sessionid': _s1, 'ds_user_id': _s2, 'x': 5},
          ),
      'top-level list with secret': () =>
          backend.data['storize.session.1'] = jsonEncode([_s1, _s2]),
      'top-level string secret': () =>
          backend.data['storize.session.1'] = jsonEncode(_s1),
      'platform exception carrying secret': () =>
          backend.readError = PlatformException(
            code: 'x',
            message: 'decrypt failed for $_s1',
            details: _s2,
          ),
      'FormatException carrying secret': () =>
          backend.readError = FormatException('bad $_s1', _s2, 3),
      'StateError carrying secret': () =>
          backend.readError = StateError('boom $_s3'),
      'missing required cookie': () => backend.data['storize.session.1'] = _env(
        1,
        cookies: {'ds_user_id': _s2, 'csrftoken': _s3},
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () async {
        entry.value();
        Object? thrown;
        SessionBlob? result;
        await capture(() async {
          try {
            result = await store.load(1);
          } on Object catch (e) {
            thrown = e;
          }
        });
        expect(thrown, isNull, reason: 'load must never throw');
        expect(result, isNull);
        expect(reports, hasLength(1));
        _noSecret(reports, 'callback args');
        _noSecret(printed, 'print/debugPrint');
        _noSecret(store, 'store.toString');
      });
    }

    test('throwing sync and async callbacks do not leak or throw', () async {
      backend.data['storize.session.1'] = _env(2);
      for (final cb in <SessionUnreadableCallback>[
        (a, r) => throw StateError('cb $_s1'),
        (a, r) async => throw StateError('cb async $_s2'),
      ]) {
        final s = SecureStorageSessionStore(backend, onUnreadable: cb);
        Object? thrown;
        await capture(() async {
          try {
            expect(await s.load(1), isNull);
          } on Object catch (e) {
            thrown = e;
          }
        });
        expect(thrown, isNull);
        _noSecret(printed, 'print');
      }
    });

    test(
      'unhandled zone errors are not produced by a throwing callback',
      () async {
        backend.data['storize.session.1'] = _env(2);
        final errors = <Object>[];
        await runZonedGuarded(() async {
          final s = SecureStorageSessionStore(
            backend,
            onUnreadable: (a, r) async => throw StateError('cb $_s1'),
          );
          await s.load(1);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }, (e, st) => errors.add(e));
        expect(errors, isEmpty);
      },
    );

    test('save validation error and happy path print nothing', () async {
      await capture(() async {
        await store.save(1, _blob());
        await store.load(1);
        await store.clear(1);
        try {
          await store.save(
            1,
            SessionBlob(
              cookies: {'csrftoken': _s3},
              userAgent: 'x',
              capturedAt: DateTime.utc(2026),
            ),
          );
        } on ArgumentError catch (e) {
          _noSecret(e, 'ArgumentError');
          _noSecret(e.message, 'ArgumentError.message');
        }
      });
      expect(printed, isEmpty);
    });

    test('SessionBlob.toString never shows values', () {
      _noSecret(_blob(), 'SessionBlob.toString');
    });

    test('lib/security source has no print/log/debugPrint calls', () {
      final bad = RegExp(
        r'\b(print|debugPrint|log|stdout\.write|stderr\.write)\s*\(',
      );
      final files = Directory('lib/security')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final code = f
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(bad.hasMatch(code), isFalse, reason: 'logging in ${f.path}');
        expect(code.contains('dart:developer'), isFalse, reason: f.path);
      }
    });

    test(
      'save: platform error propagates (documented), vault adds no secret',
      () async {
        backend.writeError = StateError('disk full');
        Object? thrown;
        try {
          await store.save(1, _blob());
        } on Object catch (e) {
          thrown = e;
        }
        expect(thrown, isA<StateError>());
        _noSecret(thrown, 'save error');
      },
    );
  });

  group('envelope versioning', () {
    Future<String?> reasonFor(String raw) async {
      backend.data['storize.session.1'] = raw;
      reports.clear();
      final r = await store.load(1);
      if (r != null) return 'LOADED';
      return reports.single.$2;
    }

    test('v:2 unknown_version', () async {
      expect(await reasonFor(_env(2)), SessionUnreadableReason.unknownVersion);
    });
    test('v:"1" unknown_version', () async {
      expect(
        await reasonFor(_env('1')),
        SessionUnreadableReason.unknownVersion,
      );
    });
    test('v:null unknown_version', () async {
      expect(
        await reasonFor(_env(null)),
        SessionUnreadableReason.unknownVersion,
      );
    });
    test('v:0 / -1 unknown_version', () async {
      expect(await reasonFor(_env(0)), SessionUnreadableReason.unknownVersion);
      expect(await reasonFor(_env(-1)), SessionUnreadableReason.unknownVersion);
    });
    test('v:1.0 (Dart num equality) is accepted, harmless', () async {
      // Documents behaviour: 1.0 == 1 in Dart, so it loads. Safe: same shape.
      expect(await reasonFor(_env(1.0)), 'LOADED');
    });
    test('capturedAt as double is invalid_shape', () async {
      expect(
        await reasonFor(_env(1, at: 1.5)),
        SessionUnreadableReason.invalidShape,
      );
    });
    test('capturedAt as string is invalid_shape', () async {
      expect(
        await reasonFor(_env(1, at: '1000')),
        SessionUnreadableReason.invalidShape,
      );
    });
    test('empty required cookie value is invalid_shape', () async {
      expect(
        await reasonFor(_env(1, cookies: {'sessionid': '', 'ds_user_id': _s2})),
        SessionUnreadableReason.invalidShape,
      );
    });
    test('capturedAt beyond DateTime range must not make load throw', () async {
      for (final at in [
        9000000000000000000,
        8640000000000001,
        -1,
        -9000000000000000000,
      ]) {
        reports.clear();
        backend.data['storize.session.1'] = _env(1, at: at);
        Object? thrown;
        SessionBlob? r;
        try {
          r = await store.load(1);
        } on Object catch (e) {
          thrown = e;
        }
        expect(thrown, isNull, reason: 'load threw for $at: $thrown');
        expect(r, isNull);
        expect(reports, [(1, 'invalid_shape')]);
      }
      backend.data['storize.session.1'] = _env(1, at: 8640000000000000);
      expect(await store.load(1), isNotNull);
      backend.data['storize.session.1'] = _env(1, at: 0);
      expect(await store.load(1), isNotNull);
    });
    test('key naming is per account, no collisions 1 vs 11', () async {
      await store.save(1, _blob());
      await store.save(11, _blob(s1: 'ZZFAKE_other'));
      expect(backend.data.keys.toSet(), {
        'storize.session.1',
        'storize.session.11',
      });
      expect((await store.load(1))!.cookies['sessionid'], _s1);
    });
    test(
      'envelope never stores anything beyond v/cookies/userAgent/capturedAt',
      () async {
        await store.save(1, _blob());
        final m = jsonDecode(backend.data['storize.session.1']!) as Map;
        expect(m.keys.toSet(), {'v', 'cookies', 'userAgent', 'capturedAt'});
      },
    );
  });

  group('concurrency', () {
    test('load racing save returns old or new, never garbage', () async {
      backend.latency = const Duration(milliseconds: 1);
      final oldB = _blob(s1: 'ZZFAKE_OLD');
      final newB = _blob(s1: 'ZZFAKE_NEW');
      await store.save(1, oldB);
      final results = <SessionBlob?>[];
      final futures = <Future<void>>[];
      for (var i = 0; i < 30; i++) {
        futures.add(store.save(1, i.isEven ? newB : oldB));
        futures.add(store.load(1).then(results.add));
        if (i % 7 == 0) futures.add(Future.value());
      }
      await Future.wait(futures);
      expect(results, hasLength(30));
      for (final r in results) {
        expect(r == oldB || r == newB, isTrue, reason: '$r');
      }
      expect(reports, isEmpty);
    });

    test('parallel save/load/clear leaves consistent final state', () async {
      backend.latency = const Duration(milliseconds: 1);
      final results = <SessionBlob?>[];
      await Future.wait([
        for (var i = 0; i < 20; i++) ...[
          store.save(1, _blob()),
          store.load(1).then(results.add),
          store.clear(1),
        ],
      ]);
      for (final r in results) {
        expect(r == null || r == _blob(), isTrue);
      }
      final end = await store.load(1);
      expect(end == null || end == _blob(), isTrue);
      expect(reports, isEmpty);
      // Final state agrees with the backend.
      expect(backend.data.containsKey('storize.session.1'), end != null);
    });

    test('racing accounts do not bleed into each other', () async {
      backend.latency = const Duration(milliseconds: 1);
      await Future.wait([
        for (var id = 1; id <= 10; id++)
          store.save(id, _blob(s1: 'ZZFAKE_$id')),
      ]);
      for (var id = 1; id <= 10; id++) {
        expect((await store.load(id))!.cookies['sessionid'], 'ZZFAKE_$id');
      }
    });
  });

  group('parity with FakeSessionStore', () {
    test('round trip, replace, clear idempotent, missing -> null', () async {
      final fake = FakeSessionStore();
      for (final SessionStore s in [store, fake]) {
        expect(await s.load(5), isNull);
        await s.save(5, _blob());
        expect(await s.load(5), _blob());
        await s.save(5, _blob(s1: 'ZZFAKE_B'));
        expect((await s.load(5))!.cookies['sessionid'], 'ZZFAKE_B');
        await s.clear(5);
        await s.clear(5);
        expect(await s.load(5), isNull);
      }
    });

    test('both stores reject missing required cookies on save', () async {
      final bad = SessionBlob(
        cookies: {'csrftoken': _s3},
        userAgent: 'x',
        capturedAt: DateTime.utc(2026),
      );
      await expectLater(store.save(1, bad), throwsArgumentError);
      final fake = FakeSessionStore();
      await expectLater(fake.save(1, bad), throwsArgumentError);
      expect(await fake.load(1), isNull);
      try {
        await fake.save(1, bad);
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('sessionid'));
        expect(e.toString(), isNot(contains(_s3)));
      }
    });

    test(
      'DIVERGENCE: local-time capturedAt comes back UTC from real store',
      () async {
        final local = DateTime.utc(2026, 11, 19, 8).toLocal();
        await store.save(1, _blob(at: local));
        final fake = FakeSessionStore()..save(1, _blob(at: local));
        expect((await store.load(1))!.capturedAt.isUtc, isTrue);
        expect((await fake.load(1))!.capturedAt.isUtc, local.isUtc);
      },
    );
  });

  group('ADR-6 path with FakeAccountRepo', () {
    test('unreadable -> setStatus(loggedOut) visible to watchActive', () async {
      final accounts = FakeAccountRepo();
      final acc = await accounts.upsert(
        LoginAccount(
          id: LoginAccount.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: 'qa-remote-1',
          username: 'qa_user',
          status: AccountStatus.active,
          connectedAt: DateTime.utc(2026, 11, 19),
        ),
      );
      final seen = <AccountStatus?>[];
      final sub = accounts.watchActive().listen((a) => seen.add(a?.status));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final wired = SecureStorageSessionStore(
        backend,
        onUnreadable: markLoggedOutOnUnreadable(accounts),
      );
      backend.readError = PlatformException(code: 'k', message: _s1);
      expect(await wired.load(acc.id), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final now = await accounts.getActive();
      expect(now!.status, AccountStatus.loggedOut);
      expect(now.statusReason, SessionUnreadableReason.platformError);
      expect(seen.last, AccountStatus.loggedOut);
      expect(seen, contains(AccountStatus.active));
      _noSecret(now.statusReason, 'status reason');
      await sub.cancel();
    });

    test(
      'corrupt data on each reason code maps to a reason, never raw data',
      () async {
        final accounts = FakeAccountRepo();
        final acc = await accounts.upsert(
          LoginAccount(
            id: LoginAccount.unsavedId,
            platform: PlatformId.instagram,
            remoteUserId: 'qa-remote-2',
            username: 'qa_user2',
            status: AccountStatus.active,
            connectedAt: DateTime.utc(2026, 11, 19),
          ),
        );
        final wired = SecureStorageSessionStore(
          backend,
          onUnreadable: markLoggedOutOnUnreadable(accounts),
        );
        backend.data['storize.session.${acc.id}'] =
            '{"v":1,"cookies":{"sessionid":"$_s1';
        await wired.load(acc.id);
        final a = (await accounts.getActive())!;
        expect(a.status, AccountStatus.loggedOut);
        expect(a.statusReason, SessionUnreadableReason.corruptJson);
      },
    );

    test('markLoggedOut swallows repo error for a missing account', () async {
      final cb = markLoggedOutOnUnreadable(FakeAccountRepo());
      await cb(12345, SessionUnreadableReason.platformError);
    });
  });
}
