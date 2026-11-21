import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/account/account_health.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

LoginAccount _account(AccountStatus status) => LoginAccount(
  id: 1,
  platform: PlatformId.instagram,
  remoteUserId: 'ds-1',
  username: 'storize_archive',
  status: status,
  connectedAt: DateTime.utc(2026, 11, 18),
);

void main() {
  test('each login status maps to its S-13 health and badge', () {
    expect(
      accountHealthOf(_account(AccountStatus.active)),
      AccountHealth.active,
    );
    expect(
      accountHealthOf(_account(AccountStatus.needsRelogin)),
      AccountHealth.needsRelogin,
    );
    expect(
      accountHealthOf(_account(AccountStatus.restricted)),
      AccountHealth.restricted,
    );
    expect(
      accountHealthOf(_account(AccountStatus.loggedOut)),
      AccountHealth.notConnected,
    );
    expect(accountHealthOf(null), AccountHealth.notConnected);

    expect(badgeStatusOf(AccountHealth.active), StorizeStatus.active);
    expect(
      badgeStatusOf(AccountHealth.needsRelogin),
      StorizeStatus.needsRelogin,
    );
    expect(badgeStatusOf(AccountHealth.restricted), StorizeStatus.restricted);
    expect(
      badgeStatusOf(AccountHealth.notConnected),
      StorizeStatus.unavailable,
    );
  });
}
