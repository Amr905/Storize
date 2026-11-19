import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Placeholder for S-06; replaced by T-028.
class StoryViewerPage extends StatelessWidget {
  /// Creates the page for [contentId].
  const StoryViewerPage({required this.contentId, super.key});

  /// The story to open.
  final int contentId;

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenStoryViewer,
    task: 'T-028',
    detail: 'contentId=$contentId',
  );
}
