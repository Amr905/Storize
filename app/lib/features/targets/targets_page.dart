import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Placeholder for S-07; replaced by T-030.
class TargetsPage extends StatelessWidget {
  /// Creates the page.
  const TargetsPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenTargets,
    task: 'T-030',
    showSessionBanner: true,
  );
}
