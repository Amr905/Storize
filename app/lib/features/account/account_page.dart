import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/core/ui_state.dart';
import 'package:storize_app/core/ui_state_view.dart';
import 'package:storize_app/features/account/account_health.dart';
import 'package:storize_app/features/account/account_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// S-13: the Instagram login's health, with the actions that fix it.
class AccountPage extends ConsumerWidget {
  /// Creates the page.
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(activeAccountProvider);
    final ui = async.toUiState(
      retry: () => ref.invalidate(activeAccountProvider),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.screenAccount)),
      body: UiStateView<LoginAccount?>(
        state: ui,
        builder: (context, account) => _AccountBody(account: account),
      ),
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.account});

  final LoginAccount? account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = account;
    final health = accountHealthOf(a);
    final rateEvents = ref.watch(rateLimitEventsProvider).value ?? 0;

    final Widget? primaryAction = switch (health) {
      AccountHealth.needsRelogin => PrimaryButton(
        label: l10n.accLogInAgain,
        expand: true,
        onPressed: () => unawaited(context.push(Routes.loginPath)),
      ),
      AccountHealth.restricted => PrimaryButton(
        label: l10n.accLogInAnother,
        expand: true,
        onPressed: () => unawaited(context.push(Routes.loginPath)),
      ),
      AccountHealth.notConnected => PrimaryButton(
        label: l10n.accLogIn,
        expand: true,
        onPressed: () => unawaited(context.push(Routes.loginPath)),
      ),
      AccountHealth.active => null,
    };

    final problem =
        health == AccountHealth.needsRelogin ||
        health == AccountHealth.restricted;
    final tone = health == AccountHealth.restricted
        ? StorizeColors.of(context).error
        : StorizeColors.of(context).warning;
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final value = theme.textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsetsDirectional.all(StorizeSpacing.screenMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                Row(
                  children: [
                    StorizeAvatar(
                      initial: a == null || a.username.isEmpty
                          ? null
                          : a.username[0].toUpperCase(),
                      size: 56,
                    ),
                    const SizedBox(width: StorizeSpacing.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a == null
                                ? l10n.accNotConnected
                                : l10n.actAccountHandle(a.username),
                            style: theme.textTheme.titleLarge,
                          ),
                          if (a != null)
                            Text(
                              l10n.accConnected(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(a.connectedAt.toLocal()),
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (!problem) ...[
                            const SizedBox(height: StorizeSpacing.s4),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: DotStatusBadge(
                                status: badgeStatusOf(health),
                                label: health == AccountHealth.notConnected
                                    ? l10n.accNotConnected
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (problem) ...[
                  const SizedBox(height: StorizeSpacing.s16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tone.container,
                      borderRadius: StorizeRadii.cardRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(
                        StorizeSpacing.cardPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                StatusBadge.iconFor(badgeStatusOf(health)),
                                color: tone.onContainer,
                              ),
                              const SizedBox(width: StorizeSpacing.s12),
                              Expanded(
                                child: Text(
                                  StatusBadge.defaultLabel(
                                    l10n,
                                    badgeStatusOf(health),
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: tone.onContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: StorizeSpacing.s8),
                          Text(
                            health == AccountHealth.needsRelogin
                                ? l10n.accNeedsReloginBody
                                : l10n.accRestrictedBody,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: tone.onContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (a != null) ...[
                  const SizedBox(height: StorizeSpacing.s16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: StorizeRadii.cardRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: StorizeSpacing.s20,
                        vertical: StorizeSpacing.s16,
                      ),
                      child: Column(
                        children: [
                          _HealthRow(
                            label: l10n.accLastCheckLabel,
                            value: a.lastSuccessAt == null
                                ? l10n.accLastCheckNever
                                : _when(context, ref, a.lastSuccessAt!),
                            labelStyle: muted,
                            valueStyle: value,
                          ),
                          const SizedBox(height: StorizeSpacing.s16),
                          _HealthRow(
                            label: l10n.accRateLimitLabel,
                            value: '$rateEvents',
                            labelStyle: muted,
                            valueStyle: value,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: StorizeSpacing.s16),
          ?primaryAction,
          if (a != null && health != AccountHealth.notConnected) ...[
            const SizedBox(height: StorizeSpacing.s12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
                side: BorderSide(color: theme.colorScheme.outline),
                foregroundColor: theme.colorScheme.error,
                textStyle: theme.textTheme.titleMedium,
              ),
              onPressed: () => _logOut(context, ref, a),
              child: Text(l10n.accLogOut),
            ),
          ],
        ],
      ),
    );
  }

  /// The time of day, with the date added when it is not today.
  static String _when(BuildContext context, WidgetRef ref, DateTime at) {
    final mat = MaterialLocalizations.of(context);
    final local = at.toLocal();
    final now = ref.read(clockProvider).now().toLocal();
    final time = mat.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return sameDay ? time : '${mat.formatMediumDate(local)} $time';
  }

  Future<void> _logOut(
    BuildContext context,
    WidgetRef ref,
    LoginAccount account,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.accLogOutTitle,
      body: l10n.accLogOutBody,
      confirmLabel: l10n.accLogOutConfirm,
      cancelLabel: l10n.setCancel,
    );
    if (!confirmed) return;
    await ref.read(accountActionsProvider).logOut(account);
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: Text(label, style: labelStyle)),
      const SizedBox(width: StorizeSpacing.s12),
      Flexible(
        child: Text(value, style: valueStyle, textAlign: TextAlign.end),
      ),
    ],
  );
}
