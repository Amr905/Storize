import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_app/features/onboarding/setup_controller.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';

/// S-03 Permissions and battery setup. Steps re-check on resume.
class SetupPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      Future.microtask(() async {
        if (mounted) await ref.read(setupControllerProvider.notifier).refresh();
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(setupControllerProvider.notifier).refresh());
    }
  }

  Future<void> _finish() async {
    ref.read(setupFinishedProvider.notifier).mark();
    try {
      await ref
          .read(settingsRepoProvider)
          .update((s) => s.copyWith(onboardingDone: true));
    } on Object {
      // The gate is already open for this run; S-03 shows again next start.
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.libraryPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(setupControllerProvider);
    final c = ref.read(setupControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = StorizeColors.of(context).warning;

    StepStatus status(SetupStepState st) =>
        st == SetupStepState.done ? StepStatus.done : StepStatus.pending;

    final (oemName, oemSteps) = switch (s.manufacturer) {
      'samsung' => (l10n.onbOemSamsungName, l10n.onbOemSamsung),
      'xiaomi' => (l10n.onbOemXiaomiName, l10n.onbOemXiaomi),
      'oppo' => (l10n.onbOemOppoName, l10n.onbOemOppo),
      'vivo' => (l10n.onbOemVivoName, l10n.onbOemVivo),
      'huawei' => (l10n.onbOemHuaweiName, l10n.onbOemHuawei),
      _ => (l10n.onbOemOtherName, l10n.onbOemOther),
    };

    final cards = <Widget Function(int n)>[
      if (s.showStorage)
        (n) => _Checked(
          checking: s.storage == SetupStepState.checking,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StepCard(
                number: n,
                title: l10n.onbStorageTitle,
                body: l10n.onbStorageBody,
                status: status(s.storage),
                actionLabel: s.storage == SetupStepState.done
                    ? null
                    : l10n.onbAllow,
                onAction: c.allowStorage,
              ),
              if (s.storageNeedsSettings)
                StorizeTextButton(
                  label: l10n.onbOpenAppSettings,
                  onPressed: c.openAppSettings,
                ),
            ],
          ),
        ),
      (n) => _Checked(
        checking: s.notifications == SetupStepState.checking,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StepCard(
              number: n,
              title: l10n.onbNotifTitle,
              body: l10n.onbNotifBody,
              status: status(s.notifications),
              actionLabel: s.notifications == SetupStepState.done
                  ? null
                  : l10n.onbAllow,
              onAction: c.allowNotifications,
            ),
            if (s.notificationsNeedSettings)
              StorizeTextButton(
                label: l10n.onbOpenAppSettings,
                onPressed: c.openAppSettings,
              ),
          ],
        ),
      ),
      (n) => _Checked(
        checking: s.battery == SetupStepState.checking,
        child: StepCard(
          number: n,
          title: l10n.onbBatteryTitle,
          body: l10n.onbBatteryBody,
          status: status(s.battery),
          actionLabel: l10n.onbBatteryOpen,
          onAction: c.openBattery,
        ),
      ),
      (n) => StepCard(
        number: n,
        title: l10n.onbOemTitle(oemName),
        body: '${l10n.onbOemDetected}\n\n$oemSteps',
        expandable: true,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(
                  StorizeSpacing.screenMargin,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onbSetupEyebrow,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: StorizeSpacing.s4),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.screenSetup,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: StorizeSpacing.s8),
                    Text(
                      l10n.onbSetupIntro,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: StorizeSpacing.s16),
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i](i + 1),
                      const SizedBox(height: StorizeSpacing.s12),
                    ],
                    if (s.showBatteryWarning)
                      Row(
                        key: const ValueKey('onb-battery-warning'),
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: warning.color,
                          ),
                          const SizedBox(width: StorizeSpacing.s8),
                          Expanded(
                            child: Text(
                              l10n.onbBatteryWarning,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: warning.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                StorizeSpacing.screenMargin,
                0,
                StorizeSpacing.screenMargin,
                StorizeSpacing.s8,
              ),
              child: Column(
                children: [
                  PrimaryButton(
                    key: const ValueKey('onb-done'),
                    label: l10n.onbDone,
                    expand: true,
                    onPressed: () => unawaited(_finish()),
                  ),
                  StorizeTextButton(
                    key: const ValueKey('onb-skip'),
                    label: l10n.onbSkip,
                    onPressed: () => unawaited(_finish()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a thin progress bar over a card while its status re-checks.
class _Checked extends StatelessWidget {
  const _Checked({required this.checking, required this.child});

  final bool checking;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      if (checking)
        PositionedDirectional(
          top: StorizeSpacing.s16,
          end: StorizeSpacing.s16,
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: AppLocalizations.of(context).onbChecking,
            ),
          ),
        ),
    ],
  );
}
