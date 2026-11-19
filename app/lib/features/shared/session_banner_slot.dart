import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/session_banner_provider.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';

/// Shows the session banner when the account needs attention; nothing
/// otherwise (healthy, absent, loading, or error). Fix opens S-13.
class SessionBannerSlot extends ConsumerWidget {
  /// Creates the slot.
  const SessionBannerSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(sessionBannerProvider).value;
    if (kind == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final relogin = kind == SessionBannerKind.needsRelogin;
    return SessionBanner(
      kind: kind,
      title: relogin ? l10n.bannerReloginTitle : l10n.bannerRestrictedTitle,
      message: relogin ? l10n.bannerReloginBody : l10n.bannerRestrictedBody,
      fixLabel: l10n.bannerFix,
      onFix: () => context.push(Routes.accountPath),
    );
  }
}
