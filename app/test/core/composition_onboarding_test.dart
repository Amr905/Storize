import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/core/composition_production.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/features/onboarding/login_lease.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_app/features/onboarding/setup_ops.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

import 'composition_rig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CompositionRig rig;

  setUp(() => rig = CompositionRig());
  tearDown(() => rig.dispose());

  test('login lease, login platform and gate are wired', () async {
    final container = ProviderContainer(
      overrides: appOverrides(rig.composition),
    );
    addTearDown(container.dispose);

    expect(
      container.read(loginLeaseProvider),
      same(rig.composition.loginLease),
    );
    expect(
      container.read(loginPlatformProvider),
      same(rig.composition.loginPlatform),
    );
    // Loading: open, so a returning user never sees S-01.
    expect(container.read(onboardingCompleteProvider), isTrue);
  });

  test('onboarding gate follows the onboardingDone setting', () async {
    final container = ProviderContainer(
      overrides: appOverrides(rig.composition),
    );
    addTearDown(container.dispose);
    final seen = <bool>[];
    container.listen(
      onboardingCompleteProvider,
      (_, v) => seen.add(v),
      fireImmediately: true,
    );
    await pumpEventQueue();
    expect(container.read(onboardingCompleteProvider), isFalse);
    await rig.settings.update((s) => s.copyWith(onboardingDone: true));
    await pumpEventQueue();
    expect(container.read(onboardingCompleteProvider), isTrue);
  });

  test('the login platform verifies the staging id, never the active '
      'account, and sends nothing without a staged session', () async {
    final active = await rig.composition.accounts.upsert(
      LoginAccount(
        id: LoginAccount.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: '1',
        username: 'active_user',
        status: AccountStatus.active,
        connectedAt: t0,
      ),
    );
    await rig.sessions.save(
      active.id,
      SessionBlob(
        cookies: const {'sessionid': 'S', 'ds_user_id': '1'},
        userAgent: 'UA',
        capturedAt: t0,
      ),
    );

    final result = await rig.composition.loginPlatform.verifySession();

    expect(result.failureOrNull, isA<SessionInvalid>());
    expect(rig.network.sends, 0);
  });

  test('the login lease can be taken and given back', () async {
    final lease = rig.composition.loginLease;
    expect(await lease.tryAcquire(LoginLease.owner), isTrue);
    await lease.release(LoginLease.owner);
  });

  group('productionSetupOps', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late SetupOps ops;

    void answer(Object? Function(MethodCall) handler) {
      messenger.setMockMethodCallHandler(storizeSystemChannel, (call) async {
        calls.add(call);
        return handler(call);
      });
    }

    setUp(() {
      calls = [];
      ops = productionSetupOps(StorizePlatformAndroid());
    });
    tearDown(
      () => messenger.setMockMethodCallHandler(storizeSystemChannel, null),
    );

    test('notification prompt maps every outcome', () async {
      for (final entry in {
        'granted': PermissionOutcome.granted,
        'denied': PermissionOutcome.denied,
        'permanentlyDenied': PermissionOutcome.permanentlyDenied,
      }.entries) {
        answer((_) => entry.key);
        expect(await ops.requestNotifications(), entry.value);
      }
      expect(calls.last.arguments, {'name': 'POST_NOTIFICATIONS'});
    });

    test('storage uses WRITE_EXTERNAL_STORAGE; checks never prompt', () async {
      answer((_) => true);
      expect(await ops.storageGranted(), isTrue);
      expect(await ops.notificationsAllowed(), isTrue);
      expect(calls.map((c) => c.method), [
        'checkPermission',
        'checkPermission',
      ]);
      expect(calls.map((c) => (c.arguments as Map)['name']), [
        'WRITE_EXTERNAL_STORAGE',
        'POST_NOTIFICATIONS',
      ]);
    });

    test('sdkInt comes from the plugin', () async {
      answer((_) => 28);
      expect(await ops.sdkInt(), 28);
    });
  });
}
