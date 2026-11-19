import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/placeholder_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_model/storize_model.dart';

/// Placeholder for S-04; replaced by T-027.
class LibraryPage extends StatelessWidget {
  /// Creates the page with the filters from the route's query parameters.
  const LibraryPage({this.kind, this.targetId, super.key});

  /// Kind filter from `?kind=`.
  final ContentKind? kind;

  /// Target filter from `?target=`.
  final int? targetId;

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: AppLocalizations.of(context).screenLibrary,
    task: 'T-027',
    detail: 'kind=${kind?.name ?? '-'} target=${targetId ?? '-'}',
    showSessionBanner: true,
  );
}
