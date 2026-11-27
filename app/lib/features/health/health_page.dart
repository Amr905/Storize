import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/ui_state.dart';
import 'package:storize_app/core/ui_state_view.dart';
import 'package:storize_app/features/health/health_providers.dart';
import 'package:storize_app/features/health/health_view.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The Health screen (FR-75): why things did or didn't download, without logs.
/// Read-only. Reached from Activity and from the session banner.
class HealthPage extends ConsumerWidget {
  /// Creates the page.
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(healthSnapshotProvider);
    final ui = async.toUiState(
      retry: () => ref.invalidate(healthSnapshotProvider),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.hltTitle),
            Text(
              l10n.hltSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            ref.invalidate(healthSnapshotProvider);
            await ref.read(healthSnapshotProvider.future);
          } on Object catch (_) {
            // The error state of the screen shows the failure.
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: UiStateView<HealthSnapshot>(
                state: ui,
                builder: (context, snapshot) => _HealthBody(snapshot: snapshot),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthBody extends StatelessWidget {
  const _HealthBody({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StorizeSpacing.screenMargin,
        vertical: StorizeSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(l10n.hltSessionTitle),
          _SessionCard(session: snapshot.session),
          const SizedBox(height: StorizeSpacing.s16),
          _SectionHeader(l10n.hltLimitsTitle),
          _LimitsCard(snapshot: snapshot),
          const SizedBox(height: StorizeSpacing.s16),
          _SectionHeader(l10n.hltAccountsTitle),
          _AccountsCard(targets: snapshot.targets, now: snapshot.at),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: StorizeSpacing.s4,
      bottom: StorizeSpacing.s8,
    ),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// A surface card with rows, as on the Settings screen.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: StorizeRadii.cardRadius,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final HealthSession? session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = session;
    final badge = switch (s?.status) {
      AccountStatus.active => const StatusBadge(status: StorizeStatus.active),
      AccountStatus.needsRelogin => const StatusBadge(
        status: StorizeStatus.needsRelogin,
      ),
      AccountStatus.restricted => const StatusBadge(
        status: StorizeStatus.restricted,
      ),
      _ => null,
    };
    if (s == null || s.status == AccountStatus.loggedOut) {
      return _Card(
        children: [
          Padding(
            padding: const EdgeInsets.all(StorizeSpacing.cardPadding),
            child: Text(l10n.hltSessionNone),
          ),
        ],
      );
    }
    return _Card(
      children: [
        Padding(
          padding: const EdgeInsets.all(StorizeSpacing.cardPadding),
          child: Row(
            children: [
              StorizeAvatar(initial: s.username.isEmpty ? '' : s.username[0]),
              const SizedBox(width: StorizeSpacing.s16),
              Expanded(
                child: Text(
                  '@${s.username}',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?badge,
            ],
          ),
        ),
      ],
    );
  }
}

class _LimitsCard extends StatelessWidget {
  const _LimitsCard({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final budget = snapshot.budget;
    final schedule = snapshot.schedule;
    final paused = budget.pausedUntil;
    final fraction = budget.burst == 0
        ? 0.0
        : budget.availableNow / budget.burst;
    final interval = l10n.hltNextCheckInterval(
      schedule.storyIntervalMin,
      schedule.postIntervalMin,
    );
    final lastRun = schedule.lastRunAt == null
        ? l10n.hltNoRunYet
        : l10n.hltLastRun(
            healthAgoText(l10n, schedule.lastRunAt, snapshot.at),
          );
    return _Card(
      children: [
        Padding(
          padding: const EdgeInsets.all(StorizeSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.hltBudgetLeft(budget.availableNow, budget.burst),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: StorizeSpacing.s8),
              Semantics(
                label: l10n.hltBudgetLeft(budget.availableNow, budget.burst),
                child: ExcludeSemantics(
                  child: LinearProgressIndicator(value: fraction),
                ),
              ),
              const SizedBox(height: StorizeSpacing.s8),
              Text(
                l10n.hltBudgetRefill(budget.callsPerHour),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (paused != null) ...[
          const Divider(height: 1),
          SettingRow.info(
            title: l10n.hltPausedTitle,
            subtitle: l10n.hltPausedUntil(
              MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(paused.toLocal())),
              healthMinutesLeft(paused, snapshot.at),
            ),
            leadingIcon: Icons.pause_circle_rounded,
          ),
        ],
        const Divider(height: 1),
        SettingRow.info(
          title: l10n.hltNextCheck,
          subtitle: '$interval\n$lastRun',
          leadingIcon: Icons.schedule_rounded,
        ),
      ],
    );
  }
}

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.targets, required this.now});

  final List<HealthTarget> targets;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (targets.isEmpty) {
      return _Card(
        children: [
          Padding(
            padding: const EdgeInsets.all(StorizeSpacing.cardPadding),
            child: Text(l10n.hltNoAccounts),
          ),
        ],
      );
    }
    return _Card(
      children: [
        for (var i = 0; i < targets.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _AccountRow(target: targets[i], now: now),
        ],
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.target, required this.now});

  final HealthTarget target;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final username = target.username;
    final last = target.lastSuccessAt == null
        ? l10n.hltNoSuccess
        : l10n.hltLastSuccess(healthAgoText(l10n, target.lastSuccessAt, now));
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StorizeSpacing.cardPadding,
        vertical: StorizeSpacing.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StorizeAvatar(initial: username.isEmpty ? '' : username[0]),
          const SizedBox(width: StorizeSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(last, style: muted),
                Text(l10n.hltSavedToday(target.savedToday), style: muted),
                if (_resultBadge(l10n, healthResultOf(target))
                    case final badge?)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: StorizeSpacing.s8,
                    ),
                    child: badge,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The result pill (Ok, Nothing new, Failed: reason, Waiting, Paused).
StatusBadge? _resultBadge(AppLocalizations l10n, HealthResult result) =>
    switch (result.kind) {
      HealthResultKind.ok => StatusBadge(
        status: StorizeStatus.active,
        label: l10n.hltResultOk,
      ),
      HealthResultKind.nothingNew => StatusBadge(
        status: StorizeStatus.active,
        label: l10n.hltResultNothingNew,
      ),
      HealthResultKind.failed => StatusBadge(
        status: StorizeStatus.error,
        label: l10n.hltResultFailed(healthReasonText(l10n, result.code)),
      ),
      HealthResultKind.waiting => StatusBadge(
        status: StorizeStatus.checking,
        label: l10n.hltResultWaiting,
      ),
      HealthResultKind.paused => StatusBadge(
        status: StorizeStatus.paused,
        label: l10n.hltResultPaused,
      ),
      HealthResultKind.none => null,
    };
