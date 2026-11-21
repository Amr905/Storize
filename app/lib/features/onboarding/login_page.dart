import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/onboarding/login_controller.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';

/// S-02 Instagram login in an embedded WebView.
///
/// The page holds the WebView lease while it is open (the controller takes it
/// on start and gives it back when the page is disposed).
class LoginPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _navigated = false;
  Timer? _doneTimer;
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(loginControllerProvider.notifier);
    unawaited(
      Future.microtask(() async {
        if (mounted) await ref.read(loginControllerProvider.notifier).start();
      }),
    );
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _controller.close();
    super.dispose();
  }

  Future<void> _leave() async {
    final c = ref.read(loginControllerProvider.notifier);
    final phase = ref.read(loginControllerProvider).phase;
    if (phase != LoginPhase.connected) await c.cancel();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.welcomePath);
    }
  }

  void _done() {
    if (_navigated || !mounted) return;
    _navigated = true;
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(Routes.setupPath);
    }
  }

  Future<void> _askSwitch(LoginState s) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.onbSwitchTitle(s.username ?? ''),
      body: l10n.onbSwitchBody,
      confirmLabel: l10n.onbSwitchConfirm,
      cancelLabel: l10n.onbSwitchKeep,
    );
    if (mounted) {
      ref.read(loginControllerProvider.notifier).answerSwitch(confirm: ok);
    }
  }

  void _help() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.onbLoginHelp),
        content: Text(l10n.onbLoginHelpBody),
        actions: [
          StorizeTextButton(
            label: l10n.onbLoginClose,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginControllerProvider, (prev, next) {
      if (prev?.phase == next.phase) return;
      if (next.phase == LoginPhase.confirmSwitch) unawaited(_askSwitch(next));
      if (next.phase == LoginPhase.connected) {
        _doneTimer ??= Timer(const Duration(milliseconds: 900), _done);
      }
    });
    final s = ref.watch(loginControllerProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showWeb =
        s.phase == LoginPhase.ready ||
        s.phase == LoginPhase.connecting ||
        s.phase == LoginPhase.confirmSwitch;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.screenLogin),
          leading: IconButton(
            tooltip: l10n.onbLoginCancel,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _leave,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: s.loading || s.phase == LoginPhase.connecting
                ? LinearProgressIndicator(
                    semanticsLabel: l10n.onbLoginPageLoading,
                    value: s.phase == LoginPhase.connecting
                        ? null
                        : s.progress / 100,
                  )
                : const SizedBox(height: 4),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                StorizeSpacing.screenMargin,
                StorizeSpacing.s12,
                StorizeSpacing.screenMargin,
                StorizeSpacing.s12,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: StorizeRadii.cardRadius,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(StorizeSpacing.s12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: StorizeSpacing.s12),
                      Expanded(
                        child: Text(
                          l10n.onbLoginInfo,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: switch (s.phase) {
                LoginPhase.starting => const Center(
                  child: CircularProgressIndicator(),
                ),
                LoginPhase.connected => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 48,
                        color: StorizeColors.of(context).success.color,
                      ),
                      const SizedBox(height: StorizeSpacing.s12),
                      Text(
                        l10n.onbLoginConnected(s.username ?? ''),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                LoginPhase.error => _ErrorView(state: s),
                _ => Stack(
                  children: [
                    Positioned.fill(
                      child: ref.watch(loginWebViewBuilderProvider)(
                        context,
                        ref.read(loginControllerProvider.notifier),
                      ),
                    ),
                    if (s.phase != LoginPhase.ready)
                      Positioned.fill(
                        child: ColoredBox(
                          color: scheme.surface.withValues(alpha: 0.92),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: StorizeSpacing.s12),
                                Text(
                                  l10n.onbLoginConnecting,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              },
            ),
            if (showWeb || s.phase == LoginPhase.error)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StorizeTextButton(
                  label: l10n.onbLoginHelp,
                  icon: Icons.info_outline_rounded,
                  onPressed: _help,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.state});

  final LoginState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (icon, title, body) = switch (state.error) {
      LoginError.network => (
        Icons.wifi_off_rounded,
        l10n.onbErrNetworkTitle,
        l10n.onbErrNetworkBody,
      ),
      LoginError.page || null => (
        Icons.error_outline_rounded,
        l10n.onbErrPageTitle,
        l10n.onbErrPageBody,
      ),
      LoginError.checkpoint => (
        Icons.verified_user_outlined,
        l10n.onbErrCheckpointTitle,
        l10n.onbErrCheckpointBody,
      ),
      LoginError.unusable => (
        Icons.person_off_outlined,
        l10n.onbErrUnusableTitle,
        l10n.onbErrUnusableBody,
      ),
      LoginError.wrongAccount => (
        Icons.swap_horiz_rounded,
        l10n.onbErrWrongAccountTitle,
        l10n.onbErrWrongAccountBody(state.previousUsername ?? ''),
      ),
      LoginError.busy => (
        Icons.hourglass_empty_rounded,
        l10n.onbErrBusyTitle,
        l10n.onbErrBusyBody,
      ),
      LoginError.cancelled => (
        Icons.cancel_outlined,
        l10n.onbErrCancelledTitle,
        l10n.onbErrCancelledBody,
      ),
    };
    return EmptyState(
      icon: icon,
      title: title,
      body: body,
      actionLabel: l10n.onbTryAgain,
      onAction: () => ref.read(loginControllerProvider.notifier).retry(),
    );
  }
}
