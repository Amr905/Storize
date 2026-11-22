import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// How one S-11 entry looks and where it leads.
class ActivityEntry {
  /// Creates an entry.
  const ActivityEntry({
    required this.icon,
    required this.tone,
    required this.text,
    this.subtitle,
    this.location,
    this.actionLabel,
  });

  /// Type icon.
  final IconData icon;

  /// Icon tone.
  final ActivityTone tone;

  /// Pre-formatted sentence.
  final String text;

  /// Optional second line (gap: the time range).
  final String? subtitle;

  /// Where tapping the entry leads, or null when it is read-only.
  final String? location;

  /// Action button text (gap: Fix battery settings, session: Fix).
  final String? actionLabel;
}

/// Maps [event] to its tone, icon, text and destination. Covers every
/// `activity_event` kind (TECH_SPEC §3).
ActivityEntry describeActivity(
  BuildContext context,
  ActivityEvent event,
  Map<int, Target> targetsById,
) {
  final l10n = AppLocalizations.of(context);
  final loc = MaterialLocalizations.of(context);
  final p = event.payload;
  final target = event.targetId == null ? null : targetsById[event.targetId];
  final account = target == null
      ? l10n.actAccountRemoved
      : l10n.actAccountHandle(target.username);
  String time(Object? ms) => ms is! int
      ? '--:--'
      : loc.formatTimeOfDay(
          TimeOfDay.fromDateTime(
            DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal(),
          ),
        );

  switch (event.type) {
    case ActivityType.checkDone:
      final checked = (p['targets'] as int?) ?? event.count;
      final failed = (p['failed'] as int?) ?? 0;
      return ActivityEntry(
        icon: Icons.check_rounded,
        tone: ActivityTone.success,
        text: l10n.actCheckDoneOk(checked),
        subtitle: failed == 0
            ? l10n.actCheckDoneOkSub
            : l10n.actCheckFailedSub(failed),
      );
    case ActivityType.downloadedStories:
    case ActivityType.downloadedPosts:
      final isStory = event.type == ActivityType.downloadedStories;
      final text = isStory
          ? l10n.actDownloadedStories(event.count)
          : l10n.actDownloadedPosts(event.count);
      final contentId = p['contentId'];
      // Opens the viewer when the entry names the item; otherwise the
      // Library filtered to this account and kind.
      final location = contentId is int
          ? (isStory
                ? Routes.storyLocation(contentId)
                : Routes.postLocation(contentId))
          : Routes.libraryLocation(
              kind: isStory ? ContentKind.story : ContentKind.post,
              targetId: event.targetId,
            );
      return ActivityEntry(
        icon: Icons.arrow_downward_rounded,
        tone: event.severity == Severity.info
            ? ActivityTone.info
            : ActivityTone.warning,
        text: text,
        subtitle: account,
        location: location,
      );
    case ActivityType.removedBeforeDownload:
      return ActivityEntry(
        icon: Icons.info_outline_rounded,
        tone: ActivityTone.neutral,
        text: l10n.actRemovedTitle,
        subtitle: l10n.actRemovedBeforeDownload(account),
      );
    case ActivityType.gap:
      return ActivityEntry(
        icon: Icons.warning_amber_rounded,
        tone: ActivityTone.warning,
        text: l10n.actGapTitle(time(p['fromMs']), time(p['toMs'])),
        subtitle: l10n.actGapSub,
        location: Routes.setupPath,
        actionLabel: l10n.actFixBattery,
      );
    case ActivityType.rateLimited:
      return ActivityEntry(
        icon: Icons.warning_amber_rounded,
        tone: ActivityTone.warning,
        text: l10n.actRateLimited,
        subtitle: l10n.actRateLimitedSub,
      );
    case ActivityType.sessionProblem:
      return ActivityEntry(
        icon: Icons.cancel_outlined,
        tone: ActivityTone.error,
        text: l10n.actSessionProblem,
        subtitle: l10n.actSessionProblemSub,
        location: Routes.accountPath,
        actionLabel: l10n.actFix,
      );
    case ActivityType.platformChanged:
      return ActivityEntry(
        icon: Icons.cancel_outlined,
        tone: ActivityTone.error,
        text: l10n.actPlatformChanged,
        subtitle: l10n.actPlatformChangedSub,
      );
    case ActivityType.pageModeUsed:
      return ActivityEntry(
        icon: Icons.web_rounded,
        tone: ActivityTone.info,
        text: l10n.actPageModeUsed,
      );
    case ActivityType.storageLow:
      return ActivityEntry(
        icon: Icons.storage_rounded,
        tone: ActivityTone.warning,
        text: l10n.actStorageLow,
      );
    case ActivityType.storagePaused:
      return ActivityEntry(
        icon: Icons.pause_circle_outline_rounded,
        tone: ActivityTone.error,
        text: l10n.actStoragePaused,
        subtitle: l10n.actStoragePausedSub,
      );
    case ActivityType.targetStatus:
      return ActivityEntry(
        icon: Icons.person_outline_rounded,
        tone: ActivityTone.info,
        text: l10n.actTargetStatus,
        subtitle: account,
      );
    case ActivityType.fileMissing:
      return ActivityEntry(
        icon: Icons.broken_image_outlined,
        tone: ActivityTone.warning,
        text: l10n.actFileMissing,
        subtitle: account,
      );
    case ActivityType.appCrash:
      return ActivityEntry(
        icon: Icons.bug_report_outlined,
        tone: ActivityTone.error,
        text: l10n.actAppCrash,
      );
  }
}
