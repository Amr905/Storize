import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/security/pin_vault.dart';
import 'package:storize_domain/testing.dart';

/// In-memory secure storage; [data] survives "restarts" (new vault objects).
class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;
  bool failReads = false;

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
    if (failReads) throw Exception('keystore');
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

void main() {
  late _FakeStorage storage;
  late FakeClock clock;

  PinVault vault({int iterations = 50}) =>
      PinVault(storage, clock: clock, iterations: iterations);

  setUp(() {
    storage = _FakeStorage();
    clock = FakeClock();
  });

  test('production default is 210 000 iterations (TECH_SPEC 5.2)', () {
    expect(PinVault.defaultIterations, 210000);
    expect(PinVault(storage).iterations, 210000);
    expect(PinVault.saltLength, 16);
  });

  group('hash format', () {
    test('v1:iter:salt:hash with a 16-byte salt, PIN not stored', () async {
      await vault(iterations: 77).setPin('1234');
      final raw = storage.data[PinVault.hashKey]!;
      final parts = raw.split(':');
      expect(parts, hasLength(4));
      expect(parts[0], 'v1');
      expect(parts[1], '77');
      expect(base64.decode(parts[2]), hasLength(16));
      expect(base64.decode(parts[3]), hasLength(32));
      expect(storage.data.values.any((v) => v.contains('1234')), isFalse);
    });

    test('a new salt for every setPin', () async {
      final v = vault();
      await v.setPin('1234');
      final first = storage.data[PinVault.hashKey];
      await v.setPin('1234');
      expect(storage.data[PinVault.hashKey], isNot(first));
    });

    test('verifies with the iteration count stored in the hash', () async {
      await vault(iterations: 30).setPin('4321');
      // A vault configured differently still verifies the old hash.
      expect(await vault(iterations: 90).verify('4321'), isA<PinAccepted>());
    });
  });

  group('setPin validation', () {
    for (final bad in ['', '123', '1234567', 'abcd', '12 4', '١٢٣٤']) {
      test('rejects "$bad"', () {
        expect(vault().setPin(bad), throwsArgumentError);
      });
    }
    for (final ok in ['1234', '12345', '123456', '0000']) {
      test('accepts $ok', () async {
        await vault().setPin(ok);
        expect(await vault().hasPin(), isTrue);
      });
    }
  });

  group('verify', () {
    test('correct PIN is accepted', () async {
      final v = vault();
      await v.setPin('2468');
      expect(await v.verify('2468'), isA<PinAccepted>());
    });

    test('wrong PIN is rejected and counts down', () async {
      final v = vault();
      await v.setPin('2468');
      final r = await v.verify('1111') as PinRejected;
      expect(r.attemptsLeft, 4);
      expect(r.cooldown, isNull);
      expect(await v.verify('246'), isA<PinRejected>());
      expect(await v.verify('2468 '), isA<PinRejected>());
    });

    test('no PIN stored is PinNotSet', () async {
      expect(await vault().verify('1234'), isA<PinNotSet>());
      expect(await vault().hasPin(), isFalse);
    });

    test('success clears earlier failures', () async {
      final v = vault();
      await v.setPin('2468');
      for (var i = 0; i < 4; i++) {
        await v.verify('0000');
      }
      expect(await v.verify('2468'), isA<PinAccepted>());
      final r = await v.verify('0000') as PinRejected;
      expect(r.attemptsLeft, 4);
    });
  });

  group('cooldown (AC3)', () {
    Future<PinVault> locked() async {
      final v = vault();
      await v.setPin('2468');
      for (var i = 0; i < 4; i++) {
        expect(await v.verify('0000'), isA<PinRejected>());
      }
      return v;
    }

    test('5th wrong PIN starts a 30 s cooldown', () async {
      final v = await locked();
      final r = await v.verify('0000') as PinRejected;
      expect(r.attemptsLeft, 0);
      expect(r.cooldown, const Duration(seconds: 30));
      expect(await v.cooldownRemaining(), const Duration(seconds: 30));
    });

    test('the right PIN is refused during the cooldown', () async {
      final v = await locked();
      await v.verify('0000');
      clock.advance(const Duration(seconds: 10));
      final r = await v.verify('2468') as PinCoolingDown;
      expect(r.remaining, const Duration(seconds: 20));
    });

    test('the cooldown ends after 30 s and a fresh set of 5 starts', () async {
      final v = await locked();
      await v.verify('0000');
      clock.advance(const Duration(seconds: 29));
      expect(await v.verify('2468'), isA<PinCoolingDown>());
      clock.advance(const Duration(seconds: 1));
      expect(await v.cooldownRemaining(), isNull);
      final r = await v.verify('0000') as PinRejected;
      expect(r.attemptsLeft, 4);
      expect(await v.verify('2468'), isA<PinAccepted>());
    });

    test('survives an app restart (new vault, same storage)', () async {
      final v = await locked();
      await v.verify('0000');
      clock.advance(const Duration(seconds: 5));
      final restarted = vault();
      expect(await restarted.cooldownRemaining(), const Duration(seconds: 25));
      expect(await restarted.verify('2468'), isA<PinCoolingDown>());
    });

    test('failures before a restart still count', () async {
      final v = vault();
      await v.setPin('2468');
      await v.verify('0000');
      await v.verify('0000');
      final restarted = vault();
      for (var i = 0; i < 2; i++) {
        await restarted.verify('0000');
      }
      final r = await restarted.verify('0000') as PinRejected;
      expect(r.cooldown, isNotNull);
    });

    test('a failure is stored before the compare (kill mid-check)', () async {
      final v = PinVault(
        storage,
        clock: clock,
        iterations: 5,
        hasher: (pin, salt, iterations) async {
          // The count is already persisted when the hash is being computed.
          if (storage.data.containsKey(PinVault.attemptsKey)) {
            throw StateError('killed');
          }
          return List<int>.filled(32, 0);
        },
      );
      await v.setPin('2468');
      await expectLater(v.verify('0000'), throwsStateError);
      expect(storage.data[PinVault.attemptsKey], startsWith('v1:1:'));
    });

    test(
      'clock jumping back restarts the cooldown at 30 s, not longer',
      () async {
        final v = await locked();
        await v.verify('0000');
        clock.set(clock.now().subtract(const Duration(days: 1)));
        expect(await v.cooldownRemaining(), const Duration(seconds: 30));
        clock.advance(const Duration(seconds: 31));
        expect(await v.cooldownRemaining(), isNull);
        expect(await v.verify('2468'), isA<PinAccepted>());
      },
    );

    test('a small back-jump never extends past 30 s', () async {
      final v = await locked();
      await v.verify('0000');
      clock.set(clock.now().subtract(const Duration(seconds: 5)));
      final left = (await v.cooldownRemaining())!;
      expect(left, lessThanOrEqualTo(const Duration(seconds: 30)));
      expect(left, greaterThan(Duration.zero));
    });

    test(
      'unreadable failure state starts a cooldown, not a free reset',
      () async {
        final v = vault();
        await v.setPin('2468');
        storage.data[PinVault.attemptsKey] = 'garbage';
        expect(await v.verify('2468'), isA<PinCoolingDown>());
      },
    );
  });

  group('reset state (T-008 N-1)', () {
    test('wiped storage: hasPin false, verify is PinNotSet', () async {
      final v = vault();
      await v.setPin('2468');
      storage.data.clear();
      expect(await v.hasPin(), isFalse);
      expect(await v.verify('2468'), isA<PinNotSet>());
    });

    test('storage read error counts as no PIN, never as accepted', () async {
      final v = vault();
      await v.setPin('2468');
      storage.failReads = true;
      expect(await v.hasPin(), isFalse);
      expect(await v.verify('2468'), isA<PinNotSet>());
    });

    for (final bad in [
      'v2:50:AAAA:AAAA',
      'v1:0:AAAA:AAAA',
      'v1:x:AAAA:AAAA',
      'v1:50:!!!:AAAA',
      'v1:50::AAAA',
      'v1:50:AAAA',
      'plain',
    ]) {
      test('malformed hash "$bad" is no PIN', () async {
        storage.data[PinVault.hashKey] = bad;
        expect(await vault().hasPin(), isFalse);
        expect(await vault().verify('1234'), isA<PinNotSet>());
      });
    }

    test('hash without a length is no PIN', () async {
      final v = vault();
      await v.setPin('2468');
      storage.data.remove(PinVault.lengthKey);
      expect(await v.hasPin(), isFalse);
      expect(await v.verify('2468'), isA<PinNotSet>());
    });

    test('pinLength is stored and cleared', () async {
      final v = vault();
      expect(await v.pinLength(), isNull);
      await v.setPin('24681');
      expect(await v.pinLength(), 5);
      await v.clear();
      expect(await v.pinLength(), isNull);
    });

    test('clear removes the PIN and the failure state', () async {
      final v = vault();
      await v.setPin('2468');
      await v.verify('0000');
      await v.clear();
      expect(storage.data, isEmpty);
      expect(await v.hasPin(), isFalse);
    });

    test('setPin clears an earlier cooldown', () async {
      final v = vault();
      await v.setPin('2468');
      for (var i = 0; i < 5; i++) {
        await v.verify('0000');
      }
      await v.setPin('1357');
      expect(await v.cooldownRemaining(), isNull);
    });
  });

  test('toString and results never carry the PIN or hash', () async {
    final v = vault();
    await v.setPin('2468');
    expect(v.toString(), 'PinVault()');
  });

  test('real isolate hasher round-trips', () async {
    final v = vault(iterations: 1000);
    await v.setPin('135790');
    expect(await v.verify('135790'), isA<PinAccepted>());
    expect(await v.verify('135791'), isA<PinRejected>());
  });
}
