import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/components/buttons.dart';

/// Neutral or destructive confirmation dialog. Pops `true` on confirm and
/// `false` on cancel.
class ConfirmDialog extends StatelessWidget {
  /// Creates a dialog.
  const ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = false,
    super.key,
  });

  /// Title.
  final String title;

  /// Body.
  final String body;

  /// Confirm button text.
  final String confirmLabel;

  /// Cancel button text.
  final String cancelLabel;

  /// Confirm uses the error colours.
  final bool destructive;

  /// Shows the dialog and resolves to `true` only when confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        StorizeTextButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PrimaryButton(
          label: confirmLabel,
          destructive: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
