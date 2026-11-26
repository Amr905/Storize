import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Section header such as "Today" (S-04, S-11).
class DateHeader extends StatelessWidget {
  /// Creates a header.
  const DateHeader({required this.label, this.trailing, super.key});

  /// Header text.
  final String label;

  /// Optional trailing widget (e.g. a count).
  final Widget? trailing;

  /// Height of the header row.
  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: StorizeSpacing.s16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// A [DateHeader] that sticks to the top of a `CustomScrollView`.
class SliverDateHeader extends StatelessWidget {
  /// Creates a sticky header sliver.
  const SliverDateHeader({required this.label, this.trailing, super.key});

  /// Header text.
  final String label;

  /// Optional trailing widget.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _DateHeaderDelegate(label: label, trailing: trailing),
    );
  }
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateHeaderDelegate({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  double get minExtent => DateHeader.height;

  @override
  double get maxExtent => DateHeader.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: DateHeader(label: label, trailing: trailing),
    );
  }

  @override
  bool shouldRebuild(_DateHeaderDelegate old) =>
      old.label != label || old.trailing != trailing;
}
