import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Placeholder for S-09; replaced by T-031.
class TargetDetailPage extends StatelessWidget {
  /// Creates the page for [targetId].
  const TargetDetailPage({required this.targetId, super.key});

  /// The target to show.
  final int targetId;

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenTargetDetail,
    task: 'T-031',
    detail: 'targetId=$targetId',
  );
}
