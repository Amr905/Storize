import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/features/link/link_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/app_router.dart';
import 'package:storize_app/router/routes.dart';

/// When the app comes back to the front and the clipboard holds an Instagram
/// link that was not offered yet, shows a one-time snackbar "Save the copied
/// Instagram link?" (FR-80, nice to have). The action opens Save from link
/// with the link. Nothing is looked up before the user taps.
///
/// It stays quiet while the app is locked or onboarding is not finished. The
/// copied text is kept in memory only, to offer each link once.
class ClipboardLinkOffer extends ConsumerStatefulWidget {
  /// Wraps [child].
  const ClipboardLinkOffer({required this.child, super.key});

  /// The app.
  final Widget child;

  @override
  ConsumerState<ClipboardLinkOffer> createState() => _ClipboardLinkOfferState();
}

class _ClipboardLinkOfferState extends ConsumerState<ClipboardLinkOffer>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_offer());
  }

  Future<void> _offer() async {
    if (ref.read(appLockedProvider) || !ref.read(onboardingCompleteProvider)) {
      return;
    }
    final text = await clipboardInstagramText(
      ref.read(clipboardTextReaderProvider),
    );
    if (!mounted || text == null) return;
    if (ref.read(handledClipboardTextProvider) == text) return;
    ref.read(handledClipboardTextProvider.notifier).mark(text);
    final router = ref.read(routerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.lnkOfferSnack),
          action: SnackBarAction(
            label: l10n.lnkOfferAction,
            onPressed: () => unawaited(
              router.push(Routes.saveFromLinkLocation(text: text)),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
