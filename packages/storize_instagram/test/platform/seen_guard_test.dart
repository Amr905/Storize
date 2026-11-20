// T-014 R2-F5: the seen breaker is persisted through SeenBreakerStore.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';

import 'support.dart';

void main() {
  test('the default store is in memory and the guard starts untripped', () {
    expect(SeenGuard().tripped, isFalse);
    expect(SeenGuard.shared.tripped, isFalse);
  });

  group('trip', () {
    test('latches memory at once and writes the store', () async {
      final store = CountingSeenStore();
      final guard = SeenGuard(store: store)..trip();
      expect(guard.tripped, isTrue, reason: 'synchronous');
      await guard.flush();
      expect(store.value, isTrue);
      expect(store.writes, 1);
    });

    test('a second guard on the same store (the other isolate) sees it after '
        'refresh, not before', () async {
      final store = CountingSeenStore();
      final a = SeenGuard(store: store);
      final b = SeenGuard(store: store);
      a.trip();
      await a.flush();
      expect(b.tripped, isFalse, reason: 'memory only until refresh');
      expect(await b.refresh(), isTrue);
      expect(b.tripped, isTrue);
    });

    test(
      'a "restart" (a new guard on the persisted store) is still tripped',
      () async {
        final store = CountingSeenStore();
        SeenGuard(store: store).trip();
        await Future<void>.delayed(Duration.zero);
        final restarted = SeenGuard(store: store);
        expect(restarted.tripped, isFalse);
        expect(await restarted.refresh(), isTrue);
      },
    );

    test('a failing write is swallowed: memory stays tripped', () async {
      final store = CountingSeenStore()..throwOnWrite = true;
      final guard = SeenGuard(store: store)..trip();
      await guard.flush();
      expect(guard.tripped, isTrue);
      expect(store.value, isFalse);
      store.throwOnWrite = false;
      guard.trip(); // retry
      await guard.flush();
      expect(store.value, isTrue);
    });
  });

  group('refresh', () {
    test('reads the store each time', () async {
      final store = CountingSeenStore();
      final guard = SeenGuard(store: store);
      await guard.refresh();
      await guard.refresh();
      expect(store.reads, 2);
      expect(guard.tripped, isFalse);
    });

    test('a stored "not tripped" never clears a memory trip', () async {
      final store = CountingSeenStore();
      final guard = SeenGuard(store: store)..trip();
      store.value = false; // a write that was lost
      expect(await guard.refresh(), isTrue);
    });

    test('a store that cannot be read fails closed', () async {
      final store = CountingSeenStore()..throwOnRead = true;
      final guard = SeenGuard(store: store);
      expect(await guard.refresh(), isTrue);
      expect(guard.tripped, isTrue);
    });
  });

  group('reset is the only way back', () {
    test('clears memory and the store', () async {
      final store = CountingSeenStore();
      final guard = SeenGuard(store: store)..trip();
      await guard.reset();
      expect(guard.tripped, isFalse);
      expect(store.value, isFalse);
      expect(store.clears, 1);
      expect(await guard.refresh(), isFalse);
    });

    test('refresh, time and a new guard never clear it', () async {
      final store = CountingSeenStore(value: true);
      for (var i = 0; i < 3; i++) {
        final guard = SeenGuard(store: store);
        expect(await guard.refresh(), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(store.clears, 0);
      expect(store.value, isTrue);
    });

    test(
      'a store that cannot clear keeps the breaker tripped in memory',
      () async {
        final store = CountingSeenStore()..throwOnClear = true;
        final guard = SeenGuard(store: store)..trip();
        await expectLater(guard.reset(), throwsA(isA<StateError>()));
        expect(guard.tripped, isTrue);
      },
    );
  });

  test('InMemorySeenBreakerStore round trip', () async {
    final s = InMemorySeenBreakerStore();
    expect(await s.isTripped(), isFalse);
    await s.markTripped();
    expect(await s.isTripped(), isTrue);
    await s.clear();
    expect(await s.isTripped(), isFalse);
  });
}
