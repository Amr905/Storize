import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Placeholder; replaced by T-030.
class AddTargetPage extends StatelessWidget {
  /// Creates the page.
  const AddTargetPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenAddTarget,
    task: 'T-030',
  );
}
