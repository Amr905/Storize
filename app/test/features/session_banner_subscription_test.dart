// QA: the banner must subscribe to watchActive() once (F-4), however many
// tabs show a banner slot and however often the user switches tabs.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/app.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/router/app_router.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../helpers/app_harness.dart';

/// Rejects a second listener on one stream, like a real single-subscription
/// stream, and counts calls.
class _StrictAccountRepo implements AccountRepo {
  final FakeAccountRepo inner = FakeAccountRepo();
  int watchCalls = 0;
  int activeListeners = 0;
  int maxListeners = 0;

  @override
  Stream<LoginAccount?> watchActive() {
    watchCalls++;
    final source = inner.watchActive();
    return Stream<LoginAccount?>.multi((c) {
      activeListeners++;
      if (activeListeners > maxListeners) maxListeners = activeListeners;
      final sub = source.listen(c.add, onError: c.addError, onDone: c.close);
      c.onCancel = () {
        activeListeners--;
        return sub.cancel();
      };
    });
  }

  @override
  Future<LoginAccount?> getActive() => inner.getActive();

  @override
  Future<LoginAccount> upsert(LoginAccount account) => inner.upsert(account);

  @override
  Future<void> setStatus(
    int id,
    AccountStatus status, {
    String? reason,
    DateTime? lastSuccessAt,
  }) =>
      inner.setStatus(id, status, reason: reason, lastSuccessAt: lastSuccessAt);
}

void main() {
  testWidgets('one watchActive subscription across all tabs and switches', (
    t,
  ) async {
    final repo = _StrictAccountRepo();
    await t.pumpWidget(
      StorizeApp(
        overrides: [
          accountRepoProvider.overrideWithValue(repo),
          appLockTestBypassProvider.overrideWithValue(true),
        ],
      ),
    );
    await t.pumpAndSettle();
    final router = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
    ).read(routerProvider);
    await repo.inner.upsert(account(AccountStatus.needsRelogin));
    await t.pumpAndSettle();
    for (final tab in ['/targets', '/activity', '/settings', '/library']) {
      router.go(tab);
      await t.pumpAndSettle();
    }
    expect(find.byType(SessionBanner), findsOneWidget);
    expect(repo.watchCalls, 1);
    expect(repo.maxListeners, 1);
    expect(t.takeException(), isNull);
  });
}
