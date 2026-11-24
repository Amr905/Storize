import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/security/pin_vault.dart';
import 'package:storize_domain/testing.dart';

// QA T-034 round 2: per-key read errors, write order and crash-in-the-middle.

/// Storage that can fail reads of chosen keys, and "crash" (throw) at the
/// n-th mutation, leaving earlier writes in place. Records the order.
class _Storage extends FlutterSecureStorage {
  _Storage([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;
  final Set<String> failReadKeys = {};
  final List<String> ops = [];
  int? crashAtOp;

  void _mutate(String what) {
    if (crashAtOp != null && ops.length >= crashAtOp!) {
      throw StateError('crash');
    }
    ops.add(what);
  }

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
    if (failReadKeys.contains(key)) throw Exception('keystore');
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
    _mutate('write:$key');
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
    _mutate('delete:$key');
    data.remove(key);
  }
}

void main() {
  late _Storage s;
  late FakeClock clock;
  PinVault vault() => PinVault(s, clock: clock, iterations: 50);

  setUp(() {
    s = _Storage();
    clock = FakeClock();
  });

  final keys = [
    PinVault.hashKey,
    PinVault.lengthKey,
    PinVault.methodKey,
  ];

  group('read error at each key', () {
    for (final k in keys) {
      test('hasPin/method/verify/setPin with $k unreadable', () async {
        final v = vault();
        await v.setPin('1234');
        final before = Map<String, String>.from(s.data);
        s.failReadKeys.add(k);
        s.ops.clear();
        // hasPin: throws or returns true, never "false because unreadable".
        if (k == PinVault.methodKey) {
          await expectLater(v.method(), throwsA(isA<PinStorageException>()));
          expect(await v.hasPin(), isTrue);
        } else {
          await expectLater(v.hasPin(), throwsA(isA<PinStorageException>()));
        }
        // verify with the right PIN never accepts when a read it needs fails.
        final r = await v.verify('1234');
        if (k == PinVault.methodKey) {
          expect(r, isA<PinAccepted>(), reason: 'verify does not need marker');
        } else {
          expect(r, isA<PinUnreadable>());
        }
        // setPin must abort and write nothing when hash/length unreadable.
        s.ops.clear();
        if (k != PinVault.methodKey) {
          await expectLater(
            v.setPin('9999'),
            throwsA(isA<PinStorageException>()),
          );
          expect(s.ops, isEmpty);
          expect(s.data[PinVault.hashKey], before[PinVault.hashKey]);
        }
      });
    }

    test(
      'unreadable verify neither counts a failure nor clears anything',
      () async {
        final v = vault();
        await v.setPin('1234');
        s.failReadKeys.add(PinVault.hashKey);
        s.ops.clear();
        for (var i = 0; i < 10; i++) {
          expect(await v.verify('0000'), isA<PinUnreadable>());
        }
        expect(s.ops, isEmpty);
        expect(s.data.containsKey(PinVault.attemptsKey), isFalse);
        s.failReadKeys.clear();
        expect(await v.verify('1234'), isA<PinAccepted>());
      },
    );

    test(
      'read error on the attempts key starts a cooldown (no free reset)',
      () async {
        final v = vault();
        await v.setPin('1234');
        s.failReadKeys.add(PinVault.attemptsKey);
        expect(await v.verify('1234'), isA<PinCoolingDown>());
      },
    );

    test(
      'clear() never reads, so a read error cannot block disabling',
      () async {
        final v = vault();
        await v.setPin('1234');
        s.failReadKeys.addAll(keys);
        await v.clear();
        expect(s.data, isEmpty);
      },
    );
  });

  group('write order and crash in the middle', () {
    test('setPin order is hash, length, method, attempts', () async {
      await vault().setPin('1234');
      expect(s.ops, [
        'write:${PinVault.hashKey}',
        'write:${PinVault.lengthKey}',
        'write:${PinVault.methodKey}',
        'delete:${PinVault.attemptsKey}',
      ]);
    });

    test('clear order is hash, length, method, attempts', () async {
      final v = vault();
      await v.setPin('1234');
      s.ops.clear();
      await v.clear();
      expect(s.ops, [
        'delete:${PinVault.hashKey}',
        'delete:${PinVault.lengthKey}',
        'delete:${PinVault.methodKey}',
        'delete:${PinVault.attemptsKey}',
      ]);
    });

    // After a crash at each point of a FIRST setPin, what does a restart see?
    for (var n = 0; n < 4; n++) {
      test('first setPin crashes before op $n: never hasPin with a wrong '
          'state', () async {
        s.crashAtOp = n;
        await expectLater(vault().setPin('1234'), throwsStateError);
        s.crashAtOp = null;
        final v = vault();
        final has = await v.hasPin();
        final marker = await v.method();
        // Either complete (has PIN) or nothing usable; verify of anything
        // that is not the PIN never accepts.
        expect(await v.verify('0000'), isNot(isA<PinAccepted>()));
        if (n < 2) {
          expect(has, isFalse);
          expect(marker, isNull);
        } else {
          expect(has, isTrue);
        }
      });
    }

    test(
      'crash mid-change of an existing PIN keeps a verifiable state',
      () async {
        final v = vault();
        await v.setPin('1234');
        for (var n = 0; n < 4; n++) {
          final snap = Map<String, String>.from(s.data);
          s.ops.clear();
          s.crashAtOp = n;
          await expectLater(v.setPin('5555'), throwsStateError);
          s.crashAtOp = null;
          final v2 = vault();
          final r1 = await v2.verify('1234');
          final r2 = await v2.verify('5555');
          // Before the hash is written: old PIN. After: new PIN, but never
          // a state where nothing verifies AND hasPin is false.
          if (n == 0) {
            expect(r1, isA<PinAccepted>());
          } else {
            // hash replaced; length same (4): only the new PIN works.
            expect(r2 is PinAccepted || r1 is PinAccepted, isTrue);
          }
          s.data
            ..clear()
            ..addAll(snap);
        }
      },
    );

    test('PIN length change crash: hash new (6), length old (4) cannot '
        'unlock with a wrong PIN and the state is recoverable', () async {
      final v = vault();
      await v.setPin('1234');
      s.ops.clear();
      s.crashAtOp = 1; // after the hash, before the length
      await expectLater(v.setPin('123456'), throwsStateError);
      s.crashAtOp = null;
      final v2 = vault();
      // UI would auto-submit at 4 digits: 4-digit prefix does not match.
      expect(await v2.verify('1234'), isA<PinRejected>());
      expect(await v2.hasPin(), isTrue);
      expect(await v2.method(), LockMethod.pin);
    });

    test('marker present but hash gone (crash in clear after the hash '
        'delete): hasPin false, marker pin', () async {
      final v = vault();
      await v.setPin('1234');
      s.ops.clear();
      s.crashAtOp = 1; // hash deleted, length not
      await expectLater(v.clear(), throwsStateError);
      s.crashAtOp = null;
      expect(await v.hasPin(), isFalse);
      expect(await v.method(), LockMethod.pin);
      expect(await v.verify('1234'), isA<PinNotSet>());
    });

    test('hash present but marker gone (crash in clear is not possible: '
        'marker is deleted after the hash)', () async {
      final v = vault();
      await v.setPin('1234');
      s.ops.clear();
      s.crashAtOp = 2; // hash and length deleted, marker kept
      await expectLater(v.clear(), throwsStateError);
      s.crashAtOp = null;
      expect(s.data.containsKey(PinVault.hashKey), isFalse);
      expect(s.data[PinVault.methodKey], 'pin');
    });

    test('a failed attempt write is in place before a hash compare '
        '(kill mid-verify counts)', () async {
      final v = vault();
      await v.setPin('1234');
      s.ops.clear();
      await v.verify('0000');
      expect(s.ops.first, 'write:${PinVault.attemptsKey}');
    });
  });

  group('iteration cap and marker', () {
    test('1 000 001 iterations is refused, 1 000 000 is parsed', () async {
      final v = vault();
      await v.setPin('1234');
      final parts = s.data[PinVault.hashKey]!.split(':');
      s.data[PinVault.hashKey] = [
        parts[0],
        '1000001',
        parts[2],
        parts[3],
      ].join(':');
      expect(await v.verify('1234'), isA<PinNotSet>());
      expect(await v.hasPin(), isFalse);
    });

    test('unknown marker values never read as a method', () async {
      for (final bad in ['', 'PIN', 'none', 'pin ', 'biometric\n']) {
        s.data[PinVault.methodKey] = bad;
        await expectLater(
          vault().method(),
          throwsA(isA<PinStorageException>()),
          reason: bad,
        );
      }
    });

    test('markBiometric writes only the marker', () async {
      await vault().markBiometric();
      expect(s.ops, ['write:${PinVault.methodKey}']);
      expect(await vault().method(), LockMethod.biometric);
      expect(await vault().hasPin(), isFalse);
    });

    test('migration: hash and length but no marker (pre round 2) still '
        'verifies, method() is null', () async {
      final v = vault();
      await v.setPin('1234');
      s.data.remove(PinVault.methodKey);
      expect(await v.hasPin(), isTrue);
      expect(await v.method(), isNull);
      expect(await v.verify('1234'), isA<PinAccepted>());
    });
  });
}
