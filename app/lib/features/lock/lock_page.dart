import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/features/lock/lock_panel.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

/// S-14: the app lock screen. Shows only the logo and the unlock controls,
/// never any app content. Unlocking opens the gate, and the router then
/// returns to the location that was asked for (including a deep link).
class LockPage extends ConsumerWidget {
  /// Creates the page.
  const LockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(lockControllerProvider);
    final controller = ref.read(lockControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(StorizeSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: StorizeSpacing.s16),
                switch (state.phase) {
                  LockPhase.locked => LockPanel(
                    title: l10n.lockTitle,
                    biometricReason: l10n.lockBiometricReason,
                    onSuccess: controller.unlock,
                  ),
                  LockPhase.failed => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.lockLoadFailed),
                      const SizedBox(height: StorizeSpacing.s16),
                      PrimaryButton(
                        label: l10n.retry,
                        onPressed: controller.refresh,
                      ),
                    ],
                  ),
                  // Checking, or already open and about to be redirected.
                  _ => const SizedBox.shrink(),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
