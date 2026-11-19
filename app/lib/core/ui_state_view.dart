import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/ui_state.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

/// Which skeleton the loading state shows.
enum UiLoadingStyle { list, grid }

/// Renders a [UiState]: skeleton, empty state, error state with Retry, or the
/// content from [builder].
///
/// Override [emptyBuilder] for screen-specific empty copy (UX state tables).
class UiStateView<T> extends StatelessWidget {
  /// Creates a view.
  const UiStateView({
    required this.state,
    required this.builder,
    this.loadingStyle = UiLoadingStyle.list,
    this.emptyBuilder,
    super.key,
  });

  /// What to render.
  final UiState<T> state;

  /// Builds the content.
  final Widget Function(BuildContext context, T value) builder;

  /// Skeleton shape.
  final UiLoadingStyle loadingStyle;

  /// Replaces the default empty state.
  final Widget Function(BuildContext context, EmptyReason reason)? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      UiLoading<T>() => switch (loadingStyle) {
        UiLoadingStyle.list => const SkeletonList(),
        UiLoadingStyle.grid => const SkeletonGrid(),
      },
      UiContent<T>(:final value) => builder(context, value),
      UiEmpty<T>(:final reason) =>
        emptyBuilder?.call(context, reason) ??
            switch (reason) {
              EmptyReason.noData => EmptyState(
                icon: Icons.inbox_outlined,
                title: l10n.emptyNoDataTitle,
                body: l10n.emptyNoDataBody,
              ),
              EmptyReason.filteredOut => EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: l10n.emptyFilteredTitle,
                body: l10n.emptyFilteredBody,
              ),
            },
      UiError<T>(:final kind, :final retry) => () {
        final (title, body, icon) = switch (kind) {
          UiErrorKind.network => (
            l10n.errorNetworkTitle,
            l10n.errorNetworkBody,
            Icons.wifi_off_rounded,
          ),
          UiErrorKind.rateLimited => (
            l10n.errorRateLimitedTitle,
            l10n.errorRateLimitedBody,
            Icons.hourglass_empty_rounded,
          ),
          UiErrorKind.platformChanged => (
            l10n.errorPlatformChangedTitle,
            l10n.errorPlatformChangedBody,
            Icons.system_update_alt_rounded,
          ),
          UiErrorKind.unknown => (
            l10n.errorUnknownTitle,
            l10n.errorUnknownBody,
            Icons.error_outline_rounded,
          ),
        };
        return EmptyState(
          icon: icon,
          title: title,
          body: body,
          actionLabel: retry == null ? null : l10n.retry,
          onAction: retry,
        );
      }(),
    };
  }
}
