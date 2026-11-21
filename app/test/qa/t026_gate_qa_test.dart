// QA (T-026): the production onboarding gate while the setting loads.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_domain/testing.dart';

void main() {
  test('FINDING: the gate reads true before the setting loads (fresh install '
      'is briefly "complete"), then false', () async {
    final container = ProviderContainer(
      overrides: [
        settingsRepoProvider.overrideWithValue(FakeSettingsRepo()),
        // Same expression as composition_production.dart:177.
        onboardingCompleteProvider.overrideWith(
          (ref) => ref.watch(onboardingDoneProvider).value ?? true,
        ),
      ],
    );
    addTearDown(container.dispose);
    final seen = <bool>[];
    container.listen(
      onboardingCompleteProvider,
      (_, v) => seen.add(v),
      fireImmediately: true,
    );
    expect(seen.first, isTrue, reason: 'open while loading');
    await pumpEventQueue();
    expect(seen.last, isFalse, reason: 'closes once the setting is read');
  });
}
