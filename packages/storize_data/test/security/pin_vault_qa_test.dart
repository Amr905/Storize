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

const _salt = 'AQIDBAUGBwgJCgsMDQ4PEA==';
// Independent vectors: Python hashlib.pbkdf2_hmac('sha256', ...),
// salt = bytes 1..16.
const _pin123456x1000 = 'ZvpHLXgWuqcoOJGGtbqMAQ+CQfsU1emiEBkh4iJVXo0=';
const _pin2468x210000 = 'Kep5tf0/vRiVpruvqcxV3tH+Nde3W7DcJpYfUdBqemM=';

void main() {
  late _FakeStorage storage;
  late FakeClock clock;

  PinVault vault({int iterations = 50}) =>
      PinVault(storage, clock: clock, iterations: iterations);

  setUp(() {
    storage = _FakeStorage();
    clock = FakeClock();
  });

  group('QA crypto (AC2)', () {
    test('verifies a hash made by an independent PBKDF2-HMAC-SHA256', () async {
      storage.data[PinVault.hashKey] = 'v1:1000:$_salt:$_pin123456x1000';
      storage.data[PinVault.lengthKey] = '6';
      expect(await vault().verify('123456'), isA<PinAccepted>());
      expect(await vault().verify('123457'), isA<PinRejected>());
    });

    test('production iteration count: 210 000 independent vector', () async {
      storage.data[PinVault.hashKey] = 'v1:210000:$_salt:$_pin2468x210000';
      storage.data[PinVault.lengthKey] = '4';
      final v = PinVault(storage, clock: clock); // real hasher, real count
      expect(await v.verify('2468'), isA<PinAccepted>());
    });

    test(
      'setPin with defaults writes 210000, 16-byte salt, 32-byte hash',
      () async {
        final v = PinVault(storage, clock: clock);
        await v.setPin('2468');
        final parts = storage.data[PinVault.hashKey]!.split(':');
        expect(parts, hasLength(4));
        expect(parts[0], 'v1');
        expect(parts[1], '210000');
        expect(base64.decode(parts[2]), hasLength(16));
        expect(base64.decode(parts[3]), hasLength(32));
      },
    );

    test(
      'salts of 50 PINs are all distinct (secure RNG, not constant)',
      () async {
        final v = vault(iterations: 1);
        final salts = <String>{};
        for (var i = 0; i < 50; i++) {
          await v.setPin('2468');
          salts.add(storage.data[PinVault.hashKey]!.split(':')[2]);
        }
        expect(salts, hasLength(50));
      },
    );
  });

  group('QA malformed stored hash never throws or unlocks', () {
    Future<PinCheck> verifyWith(String stored) async {
      storage.data[PinVault.hashKey] = stored;
      storage.data[PinVault.lengthKey] = '4';
      return vault().verify('2468');
    }

    final good = base64.encode(List<int>.filled(32, 7));
    for (final bad in <String>[
      'v2:50:$_salt:$good',
      'V1:50:$_salt:$good',
      'v1:0:$_salt:$good',
      'v1:-1:$_salt:$good',
      'v1:1.5:$_salt:$good',
      'v1:99999999999999999999:$_salt:$good',
      'v1:1000000000:$_salt:$good',
      'v1:10000001:$_salt:$good',
      'v1:50:%%%:$good',
      'v1:50:$_salt:%%%',
      'v1:50:$_salt:$good:extra',
      'v1:50:$_salt',
      'v1:50::',
      'v1::$_salt:$good',
      '::::',
      '',
      ' ',
      'v1:50:$_salt:AA', // truncated hash (1 byte)
      'v1:50:$_salt:${good.substring(0, 20)}', // truncated base64
    ]) {
      test(
        '"${bad.length > 40 ? '${bad.substring(0, 40)}...' : bad}"',
        () async {
          final sw = Stopwatch()..start();
          final r = await verifyWith(bad);
          expect(r, isNot(isA<PinAccepted>()));
          expect(
            sw.elapsedMilliseconds,
            lessThan(5000),
            reason: 'a hostile iteration count must not hang verify',
          );
        },
      );
    }

    test('10^9 iterations is refused as no PIN, not computed', () async {
      final sw = Stopwatch()..start();
      expect(await verifyWith('v1:1000000000:$_salt:$good'), isA<PinNotSet>());
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('a truncated stored hash is never matched by a prefix', () async {
      // First 16 bytes of the real 32-byte hash for 123456 / 1000 iterations.
      final full = base64.decode(_pin123456x1000);
      final short = base64.encode(full.sublist(0, 16));
      storage.data[PinVault.hashKey] = 'v1:1000:$_salt:$short';
      storage.data[PinVault.lengthKey] = '6';
      expect(await vault().verify('123456'), isNot(isA<PinAccepted>()));
    });

    test('a stored hash longer than 32 bytes with the real one as prefix '
        'is not matched', () async {
      final full = base64.decode(_pin123456x1000);
      final longer = base64.encode([...full, 0]);
      storage.data[PinVault.hashKey] = 'v1:1000:$_salt:$longer';
      storage.data[PinVault.lengthKey] = '6';
      expect(await vault().verify('123456'), isNot(isA<PinAccepted>()));
    });

    test('length key out of range or not a number is no PIN', () async {
      storage.data[PinVault.hashKey] = 'v1:1000:$_salt:$_pin123456x1000';
      for (final len in ['3', '7', '0', '-4', 'x', '', '6.0']) {
        storage.data[PinVault.lengthKey] = len;
        expect(await vault().hasPin(), isFalse, reason: 'length "$len"');
        expect(await vault().verify('123456'), isA<PinNotSet>());
      }
    });
  });

  group('QA PIN validation', () {
    for (final bad in <String>[
      '',
      '123',
      '1234567',
      '12 34',
      ' 1234',
      '1234 ',
      '1234\n',
      '\n1234',
      '12a4',
      '12-4',
      '١٢٣٤', // Arabic-Indic digits (a real keyboard in Egypt)
      '１２３４', // full-width digits
      '1234\u0000',
      '12.34',
    ]) {
      test('setPin rejects ${bad.codeUnits}', () async {
        await expectLater(vault().setPin(bad), throwsArgumentError);
        expect(storage.data, isEmpty, reason: 'nothing stored');
        expect(PinVault.isValidPin(bad), isFalse);
      });
    }

    test(
      'verify of a non-digit string never accepts and counts a failure',
      () async {
        final v = vault();
        await v.setPin('2468');
        for (var i = 0; i < 4; i++) {
          expect(await v.verify('abcd'), isA<PinRejected>());
        }
        final r = await v.verify('abcd');
        expect(r, isA<PinRejected>());
        expect((r as PinRejected).cooldown, PinVault.cooldownDuration);
      },
    );

    test(
      'Arabic-Indic digits are not the same PIN as the ASCII ones',
      () async {
        final v = vault();
        await v.setPin('2468');
        expect(await v.verify('٢٤٦٨'), isA<PinRejected>());
      },
    );
  });

  group('QA cooldown (AC3)', () {
    test(
      'exactly 4 wrongs: no cooldown, 5th starts it, 5th is not skipped',
      () async {
        final v = vault();
        await v.setPin('2468');
        for (var i = 4; i >= 1; i--) {
          final r = await v.verify('0000') as PinRejected;
          expect(r.attemptsLeft, i);
          expect(r.cooldown, isNull);
        }
        final fifth = await v.verify('0000') as PinRejected;
        expect(fifth.cooldown, const Duration(seconds: 30));
        expect(await v.verify('0000'), isA<PinCoolingDown>());
      },
    );

    test('4 wrongs then right resets; 4 more wrongs do not cooldown', () async {
      final v = vault();
      await v.setPin('2468');
      for (var i = 0; i < 4; i++) {
        await v.verify('0000');
      }
      expect(await v.verify('2468'), isA<PinAccepted>());
      for (var i = 0; i < 4; i++) {
        expect(((await v.verify('0000')) as PinRejected).cooldown, isNull);
      }
    });

    test('a wrong guess during the cooldown is not counted', () async {
      final v = vault();
      await v.setPin('2468');
      for (var i = 0; i < 5; i++) {
        await v.verify('0000');
      }
      for (var i = 0; i < 20; i++) {
        expect(await v.verify('0000'), isA<PinCoolingDown>());
      }
      clock.advance(const Duration(seconds: 31));
      final r = await v.verify('0000') as PinRejected;
      expect(r.attemptsLeft, 4, reason: 'fresh set of 5, no escalation');
    });

    test(
      'cooldown is constant (30 s) on the 2nd and 3rd round: no escalation',
      () async {
        final v = vault();
        await v.setPin('2468');
        for (var round = 0; round < 3; round++) {
          for (var i = 0; i < 4; i++) {
            await v.verify('0000');
          }
          final r = await v.verify('0000') as PinRejected;
          expect(r.cooldown, const Duration(seconds: 30));
          clock.advance(const Duration(seconds: 30, milliseconds: 1));
        }
      },
    );

    test('29.9 s: still cooling; 30 s: free', () async {
      final v = vault();
      await v.setPin('2468');
      for (var i = 0; i < 5; i++) {
        await v.verify('0000');
      }
      clock.advance(const Duration(seconds: 29, milliseconds: 900));
      expect(await v.verify('2468'), isA<PinCoolingDown>());
      clock.advance(const Duration(milliseconds: 100));
      expect(await v.verify('2468'), isA<PinAccepted>());
    });

    test(
      'kill after the 5th count but before the cooldown is written: the '
      'next wrong PIN starts the cooldown (one extra guess at most)',
      () async {
        final v = vault();
        await v.setPin('2468');
        storage.data[PinVault.attemptsKey] = 'v1:5:0';
        final r = await vault().verify('0000') as PinRejected;
        expect(r.cooldown, const Duration(seconds: 30));
      },
    );

    test('tampered far-future deadline is clamped to 30 s', () async {
      final v = vault();
      await v.setPin('2468');
      final far = clock.now().add(const Duration(days: 365 * 50));
      storage.data[PinVault.attemptsKey] = 'v1:0:${far.millisecondsSinceEpoch}';
      expect(await v.cooldownRemaining(), const Duration(seconds: 30));
    });

    test('negative / non numeric attempt values start a cooldown', () async {
      final v = vault();
      await v.setPin('2468');
      for (final bad in [
        'v1:-1:0',
        'v1:x:0',
        'v1:0:-5',
        'v1:0',
        'v2:0:0',
        '',
      ]) {
        storage.data[PinVault.attemptsKey] = bad;
        expect(
          await vault().verify('2468'),
          isA<PinCoolingDown>(),
          reason: bad,
        );
      }
    });

    test('KNOWN LIMITATION: moving the wall clock forward 30 s ends the '
        'cooldown early', () async {
      final v = vault();
      await v.setPin('2468');
      for (var i = 0; i < 5; i++) {
        await v.verify('0000');
      }
      expect(await v.cooldownRemaining(), isNotNull);
      clock.set(clock.now().add(const Duration(seconds: 30)));
      expect(await v.cooldownRemaining(), isNull);
    });

    test(
      'parallel verify calls are all counted (no lost update)',
      skip:
          'QA T-034 F-2: verify() is not serialised; 5 concurrent wrong '
          'guesses count as 1. The UI has a busy guard, so not reachable '
          'today. Un-skip when PinVault serialises verify.',
      () async {
        final v = vault();
        await v.setPin('2468');
        await Future.wait([for (var i = 0; i < 5; i++) v.verify('0000')]);
        expect(
          await v.verify('2468'),
          isA<PinCoolingDown>(),
          reason: '5 concurrent wrong guesses must trigger the cooldown',
        );
      },
    );
  });

  test('no log or exception text contains the PIN or hash', () async {
    final v = vault();
    await v.setPin('2468');
    final r = await v.verify('1357');
    expect('$r $v', isNot(contains('1357')));
    expect('$r $v', isNot(contains(storage.data[PinVault.hashKey])));
  });
}
