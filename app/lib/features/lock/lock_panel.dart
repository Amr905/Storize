import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/features/lock/lock_service.dart';
import 'package:storize_app/features/lock/pin_setup_panel.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_data/security/pin_vault.dart';

/// Asks the user to prove who they are: the fingerprint prompt opens
/// automatically, the PIN pad is the fallback, a cooldown follows 5 wrong
/// PINs. Used by S-14 and by the "turn off app lock" confirmation.
///
/// If neither a PIN nor a biometric is usable (reset state, T-008 N-1) it
/// explains that and asks for a new PIN. It never calls [onSuccess] unless
/// the user was verified or created a new PIN.
class LockPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const LockPanel({
    required this.title,
    required this.biometricReason,
    required this.onSuccess,
    super.key,
  });

  /// Heading above the dots.
  final String title;

  /// Text of the system fingerprint prompt.
  final String biometricReason;

  /// Called after a successful biometric or PIN check, or a new PIN.
  final VoidCallback onSuccess;

  @override
  ConsumerState<LockPanel> createState() => _LockPanelState();
}

class _LockPanelState extends ConsumerState<LockPanel> {
  LockMethods? _methods;
  bool _loadFailed = false;
  String _digits = '';
  bool _wrong = false;
  bool _busy = false;
  bool _prompting = false;
  bool _autoPrompted = false;
  int _shake = 0;
  Duration? _cooldown;
  Timer? _ticker;

  AppLockService get _service => ref.read(appLockServiceProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final LockMethods methods;
    try {
      methods = await _service.methods();
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _methods = methods;
      _loadFailed = false;
      _digits = '';
    });
    _startCooldown(methods.cooldown);
    if (methods.problem == LockProblem.none &&
        methods.biometricAvailable &&
        !_autoPrompted) {
      _autoPrompted = true;
      unawaited(_promptBiometric());
    }
  }

  Future<void> _promptBiometric() async {
    if (_prompting) return;
    _prompting = true;
    final ok = await _service.authenticateBiometric(widget.biometricReason);
    _prompting = false;
    if (ok && mounted) widget.onSuccess();
  }

  void _startCooldown(Duration? remaining) {
    _ticker?.cancel();
    if (remaining == null || remaining <= Duration.zero) {
      setState(() => _cooldown = null);
      return;
    }
    setState(() {
      _cooldown = remaining;
      _wrong = false;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    final left = (_cooldown ?? Duration.zero) - const Duration(seconds: 1);
    if (left > Duration.zero) {
      setState(() => _cooldown = left);
      return;
    }
    _ticker?.cancel();
    // Ask the vault: it owns the truth (clock jumps, restarts).
    final fresh = await _service.cooldown();
    if (mounted) _startCooldown(fresh);
  }

  Future<void> _digit(int d) async {
    final length = _methods?.pinLength;
    if (length == null || _busy || _digits.length >= length) return;
    setState(() {
      _digits += '$d';
      _wrong = false;
    });
    if (_digits.length == length) await _submit();
  }

  void _backspace() {
    if (_busy || _digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _wrong = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final PinCheck result;
    try {
      result = await _service.verifyPin(_digits);
    } on Object {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case PinAccepted():
        widget.onSuccess();
      case PinRejected(:final cooldown):
        setState(() {
          _digits = '';
          _wrong = true;
          _shake++;
        });
        if (cooldown != null) _startCooldown(cooldown);
      case PinCoolingDown(:final remaining):
        setState(() => _digits = '');
        _startCooldown(remaining);
      case PinNotSet():
      case PinUnreadable():
        await _load();
    }
  }

  Future<void> _newPin(String pin) async {
    await ref.read(lockControllerProvider.notifier).replacePin(pin);
    if (mounted) widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final methods = _methods;
    if (_loadFailed) {
      return _Message(
        text: l10n.lockLoadFailed,
        action: PrimaryButton(
          label: l10n.retry,
          onPressed: () => unawaited(_load()),
        ),
      );
    }
    if (methods == null) return const SizedBox.shrink();
    if (methods.problem == LockProblem.unreadable ||
        methods.problem == LockProblem.biometricUnavailable) {
      return _Message(
        text: methods.problem == LockProblem.unreadable
            ? l10n.lockStorageUnreadable
            : l10n.lockBiometricUnavailable,
        action: PrimaryButton(
          label: l10n.retry,
          onPressed: () => unawaited(_load()),
        ),
      );
    }
    if (methods.resetRequired) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.lockResetTitle,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: StorizeSpacing.s12),
          PinSetupPanel(message: l10n.lockResetBody, onComplete: _newPin),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: StorizeSpacing.s24),
        if (methods.hasPin)
          PinPad(
            length: methods.pinLength!,
            filled: _digits.length,
            onDigit: (d) => unawaited(_digit(d)),
            onBackspace: _backspace,
            shakeTrigger: _shake,
            errorText: _wrong ? l10n.lockWrongPin : null,
            cooldown: _cooldown,
            onBiometric: methods.biometricAvailable
                ? () => unawaited(_promptBiometric())
                : null,
          )
        else
          TonalButton(
            label: l10n.lockUnlockWithBiometrics,
            icon: Icons.fingerprint_rounded,
            onPressed: () => unawaited(_promptBiometric()),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text, textAlign: TextAlign.center),
      const SizedBox(height: StorizeSpacing.s16),
      action,
    ],
  );
}
