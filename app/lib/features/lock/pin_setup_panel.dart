import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

/// Enter-twice PIN creation (S-12 enable flow, S-14 reset state).
///
/// Presentational: it collects 4 to 6 digits twice and calls [onComplete]
/// with the PIN when both entries match. The parent stores it.
class PinSetupPanel extends StatefulWidget {
  /// Creates the panel.
  const PinSetupPanel({required this.onComplete, this.message, super.key});

  /// Called with the PIN once both entries match. While it runs the button
  /// shows a spinner and the keys are ignored.
  final Future<void> Function(String pin) onComplete;

  /// Optional explanation above the pad (the reset state).
  final String? message;

  @override
  State<PinSetupPanel> createState() => _PinSetupPanelState();
}

class _PinSetupPanelState extends State<PinSetupPanel> {
  static const int _min = 4;
  static const int _max = 6;

  String _first = '';
  String _digits = '';
  bool _confirming = false;
  bool _mismatch = false;
  bool _busy = false;
  int _shake = 0;

  void _digit(int d) {
    if (_busy || _digits.length >= _max) return;
    setState(() {
      _digits += '$d';
      _mismatch = false;
    });
  }

  void _backspace() {
    if (_busy || _digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _mismatch = false;
    });
  }

  Future<void> _next() async {
    if (_digits.length < _min || _busy) return;
    if (!_confirming) {
      setState(() {
        _first = _digits;
        _digits = '';
        _confirming = true;
      });
      return;
    }
    if (_digits != _first) {
      setState(() {
        _first = '';
        _digits = '';
        _confirming = false;
        _mismatch = true;
        _shake++;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onComplete(_digits);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final length = _digits.length < _min ? _min : _digits.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message != null) ...[
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: StorizeSpacing.s16),
        ],
        Text(
          _confirming ? l10n.pinSetupConfirmTitle : l10n.pinSetupTitle,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: StorizeSpacing.s4),
        Text(
          l10n.pinSetupHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: StorizeSpacing.s24),
        PinPad(
          length: length,
          filled: _digits.length,
          onDigit: _digit,
          onBackspace: _backspace,
          shakeTrigger: _shake,
          errorText: _mismatch ? l10n.pinSetupMismatch : null,
        ),
        const SizedBox(height: StorizeSpacing.s24),
        PrimaryButton(
          label: _confirming ? l10n.pinSetupConfirm : l10n.pinSetupContinue,
          loading: _busy,
          onPressed: _digits.length >= _min ? _next : null,
        ),
      ],
    );
  }
}
