import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Placeholder for S-15; replaced by T-029.
class PostViewerPage extends StatelessWidget {
  /// Creates the page for [contentId].
  const PostViewerPage({required this.contentId, super.key});

  /// The post to open.
  final int contentId;

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenPostViewer,
    task: 'T-029',
    detail: 'contentId=$contentId',
  );
}
