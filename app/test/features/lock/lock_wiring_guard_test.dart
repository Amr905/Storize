import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/features/lock/lock_controller.dart';

// QA T-034 F-1, adapted: the lock is fail-closed. A composition root that
// forgets to wire the lock cannot ship an open app: with nothing wired the
// gate is locked (the lock screen shows a retry), and only the test-only
// opt-out `appLockTestBypassProvider` opens it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('with nothing wired the gate is locked', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen(lockControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(appLockedProvider), isTrue);
    expect(c.read(appLockTestBypassProvider), isFalse);
  });
}
