import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/deep_link.dart';

/// Placeholder for S-12; replaced by T-033.
class SettingsPage extends StatelessWidget {
  /// Creates the page, optionally scrolled to [section].
  const SettingsPage({this.section, super.key});

  /// Section to scroll to (from `?section=`).
  final SettingsSection? section;

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenSettings,
    task: 'T-033',
    detail: 'section=${section?.name ?? '-'}',
  );
}
