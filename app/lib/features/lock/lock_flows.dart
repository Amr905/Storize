import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/features/lock/lock_panel.dart';
import 'package:storize_app/features/lock/pin_setup_panel.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

/// Full-screen scaffold with a close button, used by the S-12 flows.
class _FlowScaffold extends StatelessWidget {
  const _FlowScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.pinSetupCancel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(StorizeSpacing.s24),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// S-12 "turn on app lock with a PIN": enter twice, store, then pop `true`.
class PinSetupPage extends ConsumerWidget {
  /// Creates the page.
  const PinSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _FlowScaffold(
      title: l10n.appLockChooseTitle,
      child: PinSetupPanel(
        onComplete: (pin) async {
          await ref.read(lockControllerProvider.notifier).enableWithPin(pin);
          if (context.mounted) Navigator.of(context).pop(true);
        },
      ),
    );
  }
}

/// S-12 "turn off app lock": asks for the fingerprint or PIN, then pops
/// `true`. Closing pops `false`.
class ConfirmIdentityPage extends StatelessWidget {
  /// Creates the page.
  const ConfirmIdentityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FlowScaffold(
      title: l10n.settingsAppLock,
      child: LockPanel(
        title: l10n.appLockConfirmTitle,
        biometricReason: l10n.appLockDisableReason,
        onSuccess: () => Navigator.of(context).pop(true),
      ),
    );
  }
}
