import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/storize_strings.dart';
import 'package:storize_app/ui/theme/theme.dart';
import 'package:storize_app/ui/utils/bidi.dart';

/// PIN entry pad (S-14, S-12): progress dots, 3x4 key grid, optional error
/// text with a shake and a cooldown message.
///
/// Controlled: the parent owns the entered digits and passes [filled]; it
/// bumps [shakeTrigger] to play the error shake. While [cooldown] is positive
/// every key is disabled and the remaining time is shown.
class PinPad extends StatefulWidget {
  /// Creates a PIN pad for [length] (4-6) digits.
  const PinPad({
    required this.length,
    required this.filled,
    required this.onDigit,
    required this.onBackspace,
    this.errorText,
    this.shakeTrigger = 0,
    this.cooldown,
    this.onBiometric,
    super.key,
  }) : assert(length >= 4 && length <= 6, 'PIN length must be 4-6'),
       assert(filled >= 0 && filled <= length, 'filled out of range');

  /// Number of digits.
  final int length;

  /// Digits entered so far.
  final int filled;

  /// A digit key was pressed.
  final ValueChanged<int> onDigit;

  /// Backspace pressed.
  final VoidCallback onBackspace;

  /// Error message shown under the dots.
  final String? errorText;

  /// Change this value to play the shake animation.
  final int shakeTrigger;

  /// Remaining lockout; keys disabled while > 0.
  final Duration? cooldown;

  /// Optional biometric shortcut in the bottom-start slot.
  final VoidCallback? onBiometric;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.shakeTrigger != widget.shakeTrigger &&
        !MediaQuery.disableAnimationsOf(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _locked =>
      widget.cooldown != null && widget.cooldown! > Duration.zero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = StorizeColors.of(context);
    final hasError = widget.errorText != null;
    final dotColor = hasError ? colors.error.color : scheme.primary;

    final dots = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 4) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Semantics(
        container: true,
        label: StorizeStrings.pinProgress(widget.filled, widget.length),
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.length; i++)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: StorizeSpacing.s8,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < widget.filled ? dotColor : Colors.transparent,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: const SizedBox.square(dimension: 16),
                ),
              ),
          ],
        ),
      ),
    );

    final message = _locked
        ? StorizeStrings.pinCooldown(formatDuration(widget.cooldown!))
        : widget.errorText;

    Widget key(int? digit) {
      if (digit == null) return const SizedBox.square(dimension: 72);
      return _Key(
        enabled: !_locked,
        onPressed: () => widget.onDigit(digit),
        child: Text('$digit', style: theme.textTheme.displaySmall),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dots,
        const SizedBox(height: StorizeSpacing.s12),
        SizedBox(
          height: 24,
          child: message == null
              ? null
              : Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _locked
                          ? scheme.onSurfaceVariant
                          : colors.error.color,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: StorizeSpacing.s16),
        // Number pads keep the same physical layout in RTL locales.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in const [
                [1, 2, 3],
                [4, 5, 6],
                [7, 8, 9],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: StorizeSpacing.s12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final d in row)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: StorizeSpacing.s12,
                          ),
                          child: key(d),
                        ),
                    ],
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StorizeSpacing.s12,
                    ),
                    child: widget.onBiometric == null
                        ? const SizedBox.square(dimension: 72)
                        : _Key(
                            enabled: !_locked,
                            semanticLabel: StorizeStrings.pinBiometric,
                            onPressed: widget.onBiometric!,
                            child: const Icon(Icons.fingerprint_rounded),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StorizeSpacing.s12,
                    ),
                    child: key(0),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StorizeSpacing.s12,
                    ),
                    child: _Key(
                      enabled: !_locked,
                      semanticLabel: StorizeStrings.pinDelete,
                      onPressed: widget.onBackspace,
                      child: const Icon(Icons.backspace_outlined),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.enabled,
    required this.onPressed,
    required this.child,
    this.semanticLabel,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel ?? '',
        excludeFromSemantics: true,
        child: Material(
          color: scheme.surfaceContainer,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox.square(
              dimension: 72,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: enabled
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.38),
                    size: 28,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: enabled
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.38),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
