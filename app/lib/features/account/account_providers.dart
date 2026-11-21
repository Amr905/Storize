import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The active Instagram login, or null. One repo subscription.
final activeAccountProvider = StreamProvider<LoginAccount?>(
  (ref) => ref.watch(accountRepoProvider).watchActive(),
);

/// Rate-limit events in the last 7 days (S-13 health card). One repo
/// subscription.
final rateLimitEventsProvider = StreamProvider<int>(
  (ref) => ref
      .watch(activityRepoProvider)
      .watchRecent(types: {ActivityType.rateLimited})
      .map(
        (events) =>
            events.where((e) => e.type == ActivityType.rateLimited).length,
      ),
);

/// The S-13 write actions.
final accountActionsProvider = Provider<AccountActions>(AccountActions.new);

/// Logs out. Keeps targets and downloads (UX S-13).
class AccountActions {
  /// Creates the actions on [_ref].
  AccountActions(this._ref);

  final Ref _ref;

  /// Removes the saved session, marks the login as logged out and stops
  /// every scheduled check. Targets and content stay.
  Future<void> logOut(LoginAccount account) async {
    await _ref.read(sessionStoreProvider).clear(account.id);
    await _ref
        .read(accountRepoProvider)
        .setStatus(account.id, AccountStatus.loggedOut);
    await _ref.read(schedulerProvider).cancelAll();
  }
}
