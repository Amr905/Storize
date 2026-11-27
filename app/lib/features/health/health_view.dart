import 'package:flutter/foundation.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// What the result pill of one account says (FR-75).
enum HealthResultKind { ok, nothingNew, failed, waiting, paused, none }

/// The result of an account's last check, with the failure code when failed.
@immutable
final class HealthResult {
  /// Creates a result.
  const HealthResult(this.kind, {this.code});

  /// The kind of result.
  final HealthResultKind kind;

  /// The short failure code (see [healthReasonText]); set only when failed.
  final String? code;
}

/// Maps a target row to its result pill. A user pause and a pending lookup
/// win over the last check outcome, because they say what happens next.
HealthResult healthResultOf(HealthTarget target) {
  if (target.status == TargetStatus.paused) {
    return const HealthResult(HealthResultKind.paused);
  }
  if (target.status == TargetStatus.pendingLookup) {
    return const HealthResult(HealthResultKind.waiting);
  }
  return switch (target.lastOutcome) {
    TargetCheckOutcome.ok => const HealthResult(HealthResultKind.ok),
    TargetCheckOutcome.nothingNew => const HealthResult(
      HealthResultKind.nothingNew,
    ),
    TargetCheckOutcome.failed => HealthResult(
      HealthResultKind.failed,
      code: target.lastCode,
    ),
    null => const HealthResult(HealthResultKind.none),
  };
}

/// A plain reason for a failure code. Known codes reuse the existing error
/// strings; anything else reads as "Something went wrong".
String healthReasonText(AppLocalizations l10n, String? code) => switch (code) {
  'network' => l10n.errorNetworkTitle,
  'not_visible' => l10n.hltReasonNotVisible,
  'not_found' => l10n.hltReasonNotFound,
  'schema_changed' => l10n.hltReasonSchema,
  'session' => l10n.hltReasonSession,
  'restricted' => l10n.statusRestricted,
  'rate_limited' => l10n.errorRateLimitedTitle,
  _ => l10n.errorUnknownTitle,
};

/// "just now", "12 min ago", "3 h ago" or "2 days ago", relative to [now].
String healthAgoText(AppLocalizations l10n, DateTime? at, DateTime now) {
  if (at == null) return l10n.hltNever;
  final d = now.difference(at);
  if (d.inMinutes < 1) return l10n.hltAgoJustNow;
  if (d.inHours < 1) return l10n.hltAgoMinutes(d.inMinutes);
  if (d.inDays < 1) return l10n.hltAgoHours(d.inHours);
  return l10n.hltAgoDays(d.inDays);
}

/// Whole minutes left until [until], never less than one while paused.
int healthMinutesLeft(DateTime until, DateTime now) {
  final seconds = until.difference(now).inSeconds;
  final minutes = (seconds / 60).ceil();
  return minutes < 1 ? 1 : minutes;
}
