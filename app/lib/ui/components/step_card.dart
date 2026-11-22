import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/components/buttons.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Completion state of a [StepCard].
enum StepStatus { pending, done }

/// Numbered setup step (S-03). With [expandable] the body and action are
/// hidden until the header is tapped.
class StepCard extends StatefulWidget {
  /// Creates a step card.
  const StepCard({
    required this.number,
    required this.title,
    required this.body,
    this.status = StepStatus.pending,
    this.doneLabel,
    this.actionLabel,
    this.onAction,
    this.expandable = false,
    this.initiallyExpanded = true,
    this.onExpansionChanged,
    super.key,
  });

  /// Step number (1-based).
  final int number;

  /// Title.
  final String title;

  /// Body text.
  final String body;

  /// Pending or done.
  final StepStatus status;

  /// Status text when done; defaults to the generic "Done".
  final String? doneLabel;

  /// Action button text.
  final String? actionLabel;

  /// Action tapped.
  final VoidCallback? onAction;

  /// Can collapse.
  final bool expandable;

  /// Initial expansion when [expandable].
  final bool initiallyExpanded;

  /// Reports expansion changes.
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<StepCard> {
  late bool _expanded = !widget.expandable || widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpansionChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = StorizeColors.of(context);
    final done = widget.status == StepStatus.done;
    final statusText = done
        ? (widget.doneLabel ?? AppLocalizations.of(context).stepDone)
        : AppLocalizations.of(context).stepPending;
    final showBody = !widget.expandable || _expanded;

    final badge = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? colors.success.color : scheme.surface,
        border: done ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: SizedBox.square(
        dimension: 32,
        child: Center(
          child: done
              ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
              : Text(
                  '${widget.number}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
        ),
      ),
    );

    final header = Row(
      children: [
        Expanded(child: Text(widget.title, style: theme.textTheme.titleMedium)),
        if (widget.expandable)
          Icon(
            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: scheme.onSurfaceVariant,
          ),
      ],
    );

    final semanticsLabel = AppLocalizations.of(context)
        .stepSemantics(widget.number, widget.title, statusText);

    final details = <Widget>[
      if (showBody) ...[
        Text(
          widget.body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (done)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: StorizeSpacing.s8),
            child: Row(
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: colors.success.color,
                ),
                const SizedBox(width: StorizeSpacing.s8),
                Text(
                  statusText,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.success.color,
                  ),
                ),
              ],
            ),
          ),
        if (widget.actionLabel != null) ...[
          const SizedBox(height: StorizeSpacing.s12),
          TonalButton(label: widget.actionLabel!, onPressed: widget.onAction),
        ],
      ],
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: StorizeRadii.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(StorizeSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: semanticsLabel,
              excludeSemantics: true,
              child: badge,
            ),
            const SizedBox(width: StorizeSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.expandable)
                    Semantics(
                      button: true,
                      expanded: _expanded,
                      label: semanticsLabel,
                      excludeSemantics: true,
                      onTap: _toggle,
                      child: InkWell(
                        onTap: _toggle,
                        borderRadius: StorizeRadii.chipRadius,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: StorizeSpacing.minTouchTarget,
                          ),
                          child: header,
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: header,
                      ),
                    ),
                  ...details,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
