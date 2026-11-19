import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Placeholder; replaced by T-032.
class ActivityPage extends StatelessWidget {
  /// Creates the page.
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenActivity,
    task: 'T-032',
    showSessionBanner: true,
  );
}
