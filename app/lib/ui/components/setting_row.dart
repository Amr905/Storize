import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/theme/theme.dart';

enum _SettingKind { navigation, toggle, value, info }

/// One row of a settings list (S-12): navigation, switch, value or info.
class SettingRow extends StatelessWidget {
  /// Row that opens another screen (trailing chevron, mirrors in RTL).
  const SettingRow.navigation({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leadingIcon,
    this.enabled = true,
    super.key,
  }) : _kind = _SettingKind.navigation,
       switchValue = null,
       onSwitchChanged = null,
       value = null;

  /// Row with a trailing switch.
  const SettingRow.toggle({
    required this.title,
    required bool this.switchValue,
    required ValueChanged<bool>? onChanged,
    this.subtitle,
    this.leadingIcon,
    this.enabled = true,
    super.key,
  }) : _kind = _SettingKind.toggle,
       onSwitchChanged = onChanged,
       onTap = null,
       value = null;

  /// Row showing the current value at the end; tappable when [onTap] is set.
  const SettingRow.value({
    required this.title,
    required String this.value,
    this.onTap,
    this.subtitle,
    this.leadingIcon,
    this.enabled = true,
    super.key,
  }) : _kind = _SettingKind.value,
       switchValue = null,
       onSwitchChanged = null;

  /// Read-only explanatory row.
  const SettingRow.info({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    super.key,
  }) : _kind = _SettingKind.info,
       onTap = null,
       enabled = true,
       switchValue = null,
       onSwitchChanged = null,
       value = null;

  /// Title.
  final String title;

  /// Optional second line.
  final String? subtitle;

  /// Optional leading icon.
  final IconData? leadingIcon;

  /// Greyed out when false.
  final bool enabled;

  /// Current switch state (toggle rows).
  final bool? switchValue;

  /// Switch callback (toggle rows).
  final ValueChanged<bool>? onSwitchChanged;

  /// Trailing value text (value rows).
  final String? value;

  final _SettingKind _kind;

  /// Tap callback (navigation / value rows).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final leading = leadingIcon == null ? null : Icon(leadingIcon);
    final sub = subtitle == null ? null : Text(subtitle!);
    if (_kind == _SettingKind.toggle) {
      return SwitchListTile(
        title: Text(title),
        subtitle: sub,
        secondary: leading,
        value: switchValue!,
        onChanged: enabled ? onSwitchChanged : null,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s16,
        ),
      );
    }
    final trailing = switch (_kind) {
      _SettingKind.navigation => Icon(
        Directionality.of(context) == TextDirection.rtl
            ? Icons.chevron_left_rounded
            : Icons.chevron_right_rounded,
      ),
      _SettingKind.value => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(
          value!,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      _ => null,
    };
    return ListTile(
      title: Text(title),
      subtitle: sub,
      leading: leading,
      trailing: trailing,
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}
