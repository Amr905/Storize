import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Pulsing placeholder block wrapper shared by the skeletons.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!animate) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).loading,
      container: true,
      excludeSemantics: true,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.55).animate(_c),
        child: widget.child,
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({this.height, this.width, this.radius = StorizeRadii.thumb});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(height: height, width: width),
    );
  }
}

/// Placeholder list rows (S-07, S-11).
class SkeletonList extends StatelessWidget {
  /// Creates a skeleton list.
  const SkeletonList({this.itemCount = 6, this.animate = true, super.key});

  /// Number of rows.
  final int itemCount;

  /// Pulse animation (disabled automatically with reduced motion).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      animate: animate,
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++)
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: StorizeSpacing.s16,
                vertical: StorizeSpacing.s8,
              ),
              child: SizedBox(
                height: StorizeSpacing.minRowHeight - 16,
                child: Row(
                  children: [
                    _Block(height: 40, width: 40, radius: 20),
                    SizedBox(width: StorizeSpacing.s12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Block(height: 14, width: 140, radius: 4),
                          SizedBox(height: StorizeSpacing.s8),
                          _Block(height: 12, width: 90, radius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder thumbnail grid (S-04).
class SkeletonGrid extends StatelessWidget {
  /// Creates a skeleton grid.
  const SkeletonGrid({
    this.columns = 3,
    this.itemCount = 9,
    this.aspectRatio = 9 / 16,
    this.animate = true,
    super.key,
  });

  /// Columns.
  final int columns;

  /// Tiles.
  final int itemCount;

  /// Tile width / height.
  final double aspectRatio;

  /// Pulse animation.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      animate: animate,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s16,
        ),
        child: GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: StorizeSpacing.s8,
          crossAxisSpacing: StorizeSpacing.s8,
          childAspectRatio: aspectRatio,
          children: [for (var i = 0; i < itemCount; i++) const _Block()],
        ),
      ),
    );
  }
}
