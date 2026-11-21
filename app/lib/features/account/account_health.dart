import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The four health states of S-13 (UX S-13 "States by health").
enum AccountHealth {
  /// The session works.
  active,

  /// Instagram ended the session or asked for verification.
  needsRelogin,

  /// Instagram may have restricted the account.
  restricted,

  /// No usable login.
  notConnected,
}

/// Maps the stored login (null when none) to its S-13 health state. A
/// logged-out login counts as not connected.
AccountHealth accountHealthOf(LoginAccount? account) =>
    switch (account?.status) {
      null => AccountHealth.notConnected,
      AccountStatus.active => AccountHealth.active,
      AccountStatus.needsRelogin => AccountHealth.needsRelogin,
      AccountStatus.restricted => AccountHealth.restricted,
      AccountStatus.loggedOut => AccountHealth.notConnected,
    };

/// The status badge for [health]. Gray "Not connected" uses the unavailable
/// variant with its own label.
StorizeStatus badgeStatusOf(AccountHealth health) => switch (health) {
  AccountHealth.active => StorizeStatus.active,
  AccountHealth.needsRelogin => StorizeStatus.needsRelogin,
  AccountHealth.restricted => StorizeStatus.restricted,
  AccountHealth.notConnected => StorizeStatus.unavailable,
};
