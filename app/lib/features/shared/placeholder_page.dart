import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/shared/session_banner_slot.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

/// Temporary page body used until the owning task builds the screen.
class PlaceholderPage extends StatelessWidget {
  /// Creates a placeholder.
  const PlaceholderPage({
    required this.title,
    required this.task,
    this.detail,
    this.showSessionBanner = false,
    super.key,
  });

  /// App bar title.
  final String title;

  /// The task that replaces this page, e.g. `T-027`.
  final String task;

  /// Extra line, such as the parameters the page received.
  final String? detail;

  /// Shows the session banner under the app bar (S-04, S-07, S-11).
  final bool showSessionBanner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (showSessionBanner)
            const Padding(
              padding: EdgeInsetsDirectional.all(StorizeSpacing.s16),
              child: SessionBannerSlot(),
            ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.placeholderTodo(task)),
                  if (detail != null) Text(detail!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
