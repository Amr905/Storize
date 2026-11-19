import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Placeholder; replaced by T-026.
class SetupPage extends StatelessWidget {
  /// Creates the page.
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenSetup,
    task: 'T-026',
  );
}
