import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Which session problem the banner reports.
enum SessionBannerKind { needsRelogin, restricted }

/// Banner shown on S-04 / S-07 / S-11 when the Instagram session is unhealthy.
/// Amber for needs-relogin, red for restricted; [onFix] opens S-13.
class SessionBanner extends StatelessWidget {
  /// Creates a banner. [title], [message] and [fixLabel] default to the
  /// built-in strings for [kind].
  const SessionBanner({
    required this.kind,
    required this.onFix,
    this.title,
    this.message,
    this.fixLabel,
    super.key,
  });

  /// Problem kind.
  final SessionBannerKind kind;

  /// "Fix" tapped.
  final VoidCallback onFix;

  /// Headline override.
  final String? title;

  /// Second line override.
  final String? message;

  /// Action label override.
  final String? fixLabel;

  @override
  Widget build(BuildContext context) {
    final colors = StorizeColors.of(context);
    final theme = Theme.of(context);
    final relogin = kind == SessionBannerKind.needsRelogin;
    final tone = relogin ? colors.warning : colors.error;
    final headline =
        title ??
        (relogin
            ? AppLocalizations.of(context).bannerReloginTitle
            : AppLocalizations.of(context).bannerRestrictedTitle);
    final body =
        message ??
        (relogin
            ? AppLocalizations.of(context).bannerReloginBody
            : AppLocalizations.of(context).bannerRestrictedBody);
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.container,
          borderRadius: StorizeRadii.cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: StorizeSpacing.s16,
            end: StorizeSpacing.s8,
            top: StorizeSpacing.s8,
            bottom: StorizeSpacing.s8,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  relogin ? Icons.warning_amber_rounded : Icons.report_rounded,
                  color: tone.onContainer,
                ),
              ),
              const SizedBox(width: StorizeSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tone.onContainer,
                      ),
                    ),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tone.onContainer,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onFix,
                style: TextButton.styleFrom(
                  foregroundColor: tone.onContainer,
                  textStyle: theme.textTheme.titleMedium,
                ),
                child: Text(fixLabel ?? AppLocalizations.of(context).bannerFix),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
