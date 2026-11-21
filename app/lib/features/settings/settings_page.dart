import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/ui_state.dart';
import 'package:storize_app/core/ui_state_view.dart';
import 'package:storize_app/features/account/account_health.dart';
import 'package:storize_app/features/account/account_providers.dart';
import 'package:storize_app/features/settings/app_lock_row.dart';
import 'package:storize_app/features/settings/settings_format.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_app/features/settings/settings_sheets.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/deep_link.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_data/update/update.dart';
import 'package:storize_domain/storize_domain.dart';

/// S-12: every setting in one place (FR-50).
class SettingsPage extends ConsumerStatefulWidget {
  /// Creates the page, optionally scrolled to [section].
  const SettingsPage({this.section, super.key});

  /// Section to scroll to (from `?section=`).
  final SettingsSection? section;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final GlobalKey _storageKey = GlobalKey();
  final _scroll = ScrollController();
  bool _scrolledToSection = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToSectionOnce() {
    if (_scrolledToSection || widget.section != SettingsSection.storage) {
      return;
    }
    _scrolledToSection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _storageKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsStreamProvider);
    final ui = settings.toUiState(
      retry: () => ref.invalidate(settingsStreamProvider),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.screenSettings)),
      body: UiStateView<AppSettings>(
        state: ui,
        builder: (context, s) {
          _scrollToSectionOnce();
          return _content(context, s);
        },
      ),
    );
  }

  Widget _content(BuildContext context, AppSettings s) {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(settingsActionsProvider);
    final storage = ref.watch(settingsStorageProvider);
    final update = ref.watch(updateStateProvider).value;
    final version = ref.watch(appVersionProvider);

    final Widget? updateRow = switch (update) {
      UpdateAvailable(:final version) => SettingRow.value(
        title: l10n.setUpdateAvailable,
        value: l10n.setUpdateVersion(version),
      ),
      UpdateRequired(:final version) => SettingRow.value(
        title: l10n.setUpdateRequired,
        value: l10n.setUpdateVersion(version),
      ),
      _ => null,
    };

    return ListView(
      controller: _scroll,
      children: [
        _SectionHeader(l10n.setSectionInstagram),
        const _AccountRow(),
        _SectionHeader(l10n.setSectionChecking),
        SettingRow.value(
          title: l10n.setStoryInterval,
          value: intervalLabel(l10n, s.storyIntervalMin),
          onTap: () => unawaited(_pickStoryInterval(s)),
        ),
        SettingRow.value(
          title: l10n.setPostInterval,
          value: intervalLabel(l10n, s.postIntervalMin),
          subtitle: s.postIntervalMin == 60 ? l10n.setPostOneHourWarning : null,
          onTap: () => unawaited(_pickPostInterval(s)),
        ),
        SettingRow.toggle(
          title: l10n.setWifiOnly,
          switchValue: s.wifiOnly,
          onChanged: (on) => unawaited(actions.setWifiOnly(on: on)),
        ),
        SettingRow.navigation(
          title: l10n.setKeepRunning,
          onTap: () => unawaited(context.push(Routes.setupPath)),
        ),
        _SectionHeader(l10n.setSectionNotifications),
        SettingRow.toggle(
          title: l10n.setNotifyStories,
          switchValue: s.notifyStories,
          onChanged: (on) => unawaited(actions.setNotifyStories(on: on)),
        ),
        SettingRow.toggle(
          title: l10n.setNotifyPosts,
          switchValue: s.notifyPosts,
          onChanged: (on) => unawaited(actions.setNotifyPosts(on: on)),
        ),
        SettingRow.toggle(
          title: l10n.setNotifyLogin,
          subtitle: s.notifyLogin ? null : l10n.setNotifyLoginOffWarning,
          switchValue: s.notifyLogin,
          onChanged: (on) => unawaited(actions.setNotifyLogin(on: on)),
        ),
        KeyedSubtree(
          key: _storageKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(l10n.setSectionStorage),
              SettingRow.info(
                title: l10n.setStorageLocation,
                leadingIcon: Icons.folder_outlined,
              ),
              SettingRow.navigation(
                title: _usageText(l10n, storage),
                leadingIcon: Icons.pie_chart_outline_rounded,
                onTap: () => unawaited(_showStorage()),
              ),
              SettingRow.value(
                title: l10n.setKeepDownloads,
                value: s.retentionDays == null
                    ? l10n.setKeepForever
                    : l10n.setKeepAfterDays(s.retentionDays!),
                onTap: () => unawaited(_editRetention(s)),
              ),
            ],
          ),
        ),
        _SectionHeader(l10n.setSectionSecurity),
        const AppLockRow(),
        _SectionHeader(l10n.setSectionAbout),
        SettingRow.info(title: l10n.setVersion(version)),
        ?updateRow,
        const SizedBox(height: StorizeSpacing.s24),
      ],
    );
  }

  String _usageText(AppLocalizations l10n, AsyncValue<StorageReport> storage) {
    if (storage.hasError) return l10n.setStorageUnknown;
    final report = storage.value;
    if (report == null) return l10n.setStorageCalculating;
    final used = formatBytes(l10n, report.totalBytes);
    final free = report.freeBytes;
    return free == null
        ? l10n.setStorageUsedOnly(used)
        : l10n.setStorageUsedFree(used, formatBytes(l10n, free));
  }

  Future<void> _pickStoryInterval(AppSettings s) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showIntervalSheet(
      context,
      title: l10n.setStoryInterval,
      options: AppSettings.storyIntervalOptions,
      current: s.storyIntervalMin,
    );
    if (picked == null || picked == s.storyIntervalMin) return;
    await ref.read(settingsActionsProvider).setStoryInterval(picked);
  }

  Future<void> _pickPostInterval(AppSettings s) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showIntervalSheet(
      context,
      title: l10n.setPostInterval,
      options: AppSettings.postIntervalOptions,
      current: s.postIntervalMin,
      oneHourHint: true,
    );
    if (picked == null || picked == s.postIntervalMin) return;
    await ref.read(settingsActionsProvider).setPostInterval(picked);
  }

  Future<void> _editRetention(AppSettings s) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => RetentionSheet(current: s.retentionDays),
  );

  Future<void> _showStorage() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const StorageSheet(),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          StorizeSpacing.s16,
          StorizeSpacing.s24,
          StorizeSpacing.s16,
          StorizeSpacing.s8,
        ),
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// The Instagram row: the handle and its health badge; opens S-13. While the
/// login loads it is hidden.
class _AccountRow extends ConsumerWidget {
  const _AccountRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(activeAccountProvider);
    if (!async.hasValue) return const SizedBox.shrink();
    final account = async.requireValue;
    final health = accountHealthOf(account);
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded;
    return ListTile(
      title: Text(
        account == null
            ? l10n.accLogIn
            : l10n.actAccountHandle(account.username),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            status: badgeStatusOf(health),
            label: health == AccountHealth.notConnected
                ? l10n.accNotConnected
                : null,
          ),
          const SizedBox(width: StorizeSpacing.s4),
          Icon(chevron),
        ],
      ),
      onTap: () => unawaited(context.push(Routes.accountPath)),
    );
  }
}
