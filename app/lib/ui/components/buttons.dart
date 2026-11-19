import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
        semanticsLabel: AppLocalizations.of(context).loading,
      ),
    );
  }
}

Widget _content({
  required String label,
  required IconData? icon,
  required bool loading,
  required Color spinnerColor,
}) {
  final leading = loading
      ? _Spinner(color: spinnerColor)
      : (icon == null ? null : Icon(icon, size: 18));
  if (leading == null) return Text(label);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      leading,
      const SizedBox(width: StorizeSpacing.s8),
      Flexible(child: Text(label)),
    ],
  );
}

Widget _maybeExpand(Widget child, {required bool expand}) =>
    expand ? SizedBox(width: double.infinity, child: child) : child;

/// Filled call-to-action button (fully rounded, >= 48 dp). While [loading] it
/// shows a spinner and ignores taps. [destructive] uses the error colours.
class PrimaryButton extends StatelessWidget {
  /// Creates a primary button.
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.destructive = false,
    this.expand = false,
    super.key,
  });

  /// Button text.
  final String label;

  /// Tap callback; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Shows a spinner and blocks taps.
  final bool loading;

  /// Use error colours (destructive action).
  final bool destructive;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = destructive ? scheme.error : scheme.primary;
    final fg = destructive ? scheme.onError : scheme.onPrimary;
    return _maybeExpand(
      FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: loading ? bg.withValues(alpha: 0.7) : null,
          disabledForegroundColor: loading ? fg : null,
        ),
        child: _content(
          label: label,
          icon: icon,
          loading: loading,
          spinnerColor: fg,
        ),
      ),
      expand: expand,
    );
  }
}

/// Tonal (secondary container) button with a loading state.
class TonalButton extends StatelessWidget {
  /// Creates a tonal button.
  const TonalButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    super.key,
  });

  /// Button text.
  final String label;

  /// Tap callback; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Shows a spinner and blocks taps.
  final bool loading;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _maybeExpand(
      FilledButton.tonal(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          disabledBackgroundColor: loading ? scheme.secondaryContainer : null,
          disabledForegroundColor: loading ? scheme.onSecondaryContainer : null,
        ),
        child: _content(
          label: label,
          icon: icon,
          loading: loading,
          spinnerColor: scheme.onSecondaryContainer,
        ),
      ),
      expand: expand,
    );
  }
}

/// Text button with a loading state. Named `StorizeTextButton` so it does not
/// clash with Material's `TextButton` in the same import scope.
class StorizeTextButton extends StatelessWidget {
  /// Creates a text button.
  const StorizeTextButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.destructive = false,
    super.key,
  });

  /// Button text.
  final String label;

  /// Tap callback; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Shows a spinner and blocks taps.
  final bool loading;

  /// Use error colour.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = destructive ? scheme.error : scheme.primary;
    return TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: fg,
        disabledForegroundColor: loading ? fg : null,
      ),
      child: _content(
        label: label,
        icon: icon,
        loading: loading,
        spinnerColor: fg,
      ),
    );
  }
}
