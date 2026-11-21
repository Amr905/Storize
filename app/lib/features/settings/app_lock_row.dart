import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/features/lock/lock_flows.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

enum _Method { biometric, pin }

/// The "App lock" row of S-12 with the note that gallery files are outside
/// the lock.
///
/// Turning it on: a fingerprint confirmation (when a strong biometric is
/// enrolled and the user picks it) or a PIN entered twice. Turning it off
/// needs a successful fingerprint or PIN check.
class AppLockRow extends ConsumerWidget {
  /// Creates the row.
  const AppLockRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(lockControllerProvider.select((s) => s.enabled));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingRow.toggle(
          title: l10n.settingsAppLock,
          subtitle: l10n.settingsAppLockSubtitle,
          leadingIcon: Icons.lock_outline_rounded,
          switchValue: enabled,
          onChanged: (on) =>
              on ? _enable(context, ref) : _disable(context, ref),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: StorizeSpacing.s16,
            end: StorizeSpacing.s16,
            bottom: StorizeSpacing.s8,
          ),
          child: Text(
            l10n.settingsAppLockNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(appLockServiceProvider);
    final controller = ref.read(lockControllerProvider.notifier);
    var method = _Method.pin;
    if (await service.biometricAvailable()) {
      if (!context.mounted) return;
      final picked = await showModalBottomSheet<_Method>(
        context: context,
        showDragHandle: true,
        builder: (_) => const _MethodSheet(),
      );
      if (picked == null) return;
      method = picked;
    }
    var ok = false;
    switch (method) {
      case _Method.biometric:
        if (await service.authenticateBiometric(l10n.appLockEnableReason)) {
          await controller.enableWithBiometric();
          ok = true;
        }
      case _Method.pin:
        if (!context.mounted) return;
        ok =
            await Navigator.of(context, rootNavigator: true).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const PinSetupPage(),
              ),
            ) ??
            false;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.appLockEnabled : l10n.appLockEnableFailed),
        ),
      );
  }

  Future<void> _disable(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(lockControllerProvider.notifier);
    final confirmed =
        await Navigator.of(context, rootNavigator: true).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const ConfirmIdentityPage(),
          ),
        ) ??
        false;
    if (!confirmed) return;
    await controller.disable();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.appLockDisabled)));
  }
}

class _MethodSheet extends StatelessWidget {
  const _MethodSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(StorizeSpacing.s16),
            child: Text(
              l10n.appLockChooseTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint_rounded),
            title: Text(l10n.appLockChooseBiometric),
            onTap: () => Navigator.of(context).pop(_Method.biometric),
          ),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(l10n.appLockChoosePin),
            onTap: () => Navigator.of(context).pop(_Method.pin),
          ),
        ],
      ),
    );
  }
}
