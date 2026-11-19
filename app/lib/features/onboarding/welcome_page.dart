import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Placeholder; replaced by T-026.
class WelcomePage extends StatelessWidget {
  /// Creates the page.
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenWelcome,
    task: 'T-026',
  );
}
