import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/link/link_preview_sheet.dart';
import 'package:storize_app/features/link/link_providers.dart';
import 'package:storize_app/features/preview/preview_page.dart'
    show previewFailureText;
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// Save from link (FR-80): paste or share an Instagram link, look it up and
/// save the item.
///
/// The field is filled from the clipboard when it holds an Instagram link
/// (it never looks anything up by itself). A shared link ([initialText], from
/// "Share -> Storize") is looked up at once. A lookup opens the Link preview
/// sheet.
class SaveFromLinkPage extends ConsumerStatefulWidget {
  /// Creates the page. [initialText] is a shared or copied link.
  const SaveFromLinkPage({this.initialText, super.key});

  /// A link to look up at once, or null.
  final String? initialText;

  @override
  ConsumerState<SaveFromLinkPage> createState() => _SaveFromLinkPageState();
}

class _SaveFromLinkPageState extends ConsumerState<SaveFromLinkPage> {
  final TextEditingController _field = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _errorHint;

  @override
  void initState() {
    super.initState();
    _field.addListener(() => setState(() {}));
    final initial = widget.initialText;
    if (initial != null && initial.trim().isNotEmpty) {
      _field.text = initial.trim();
      // Providers must not change while the widget tree builds.
      unawaited(
        Future<void>.microtask(() {
          if (!mounted) return;
          unawaited(_lookUp());
        }),
      );
    } else {
      unawaited(_prefillFromClipboard());
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _prefillFromClipboard() async {
    final text = await clipboardInstagramText(
      ref.read(clipboardTextReaderProvider),
    );
    if (!mounted || text == null || _field.text.isNotEmpty) return;
    _field.text = text;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted || text == null) return;
    _field.text = text.trim();
    setState(() => _error = null);
  }

  Future<void> _lookUp() async {
    final text = _field.text.trim();
    if (text.isEmpty || _busy) return;
    final l10n = AppLocalizations.of(context);
    final usecase = ref.read(saveFromLinkProvider);
    setState(() {
      _busy = true;
      _error = null;
      _errorHint = null;
    });
    final result = await usecase.lookupText(text);
    if (!mounted) return;
    String? error;
    String? hint;
    switch (result) {
      case LinkFound(:final preview):
        setState(() => _busy = false);
        await LinkPreviewSheet.show(context, preview);
        return;
      case LinkUnsupported():
        error = l10n.lnkUnsupported;
        hint = l10n.lnkUnsupportedHint;
      case LinkGone(:final kind):
        error = switch (kind) {
          LinkKind.story => l10n.lnkStoryGone,
          LinkKind.highlight => l10n.lnkHighlightGone,
          LinkKind.post || LinkKind.reel => l10n.lnkPostGone,
        };
      case LinkFailed(:final failure):
        final t = previewFailureText(l10n, failure, '');
        error = t.title;
        hint = t.body;
    }
    setState(() {
      _busy = false;
      _error = error;
      _errorHint = hint;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lnkTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(StorizeSpacing.screenMargin),
          children: [
            TextField(
              controller: _field,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => unawaited(_lookUp()),
              decoration: InputDecoration(
                labelText: l10n.lnkFieldLabel,
                hintText: l10n.lnkFieldHint,
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: l10n.lnkPaste,
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: _busy ? null : () => unawaited(_paste()),
                ),
              ),
            ),
            if (_errorHint != null && _errorHint!.isNotEmpty) ...[
              const SizedBox(height: StorizeSpacing.s8),
              Text(
                _errorHint!,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: StorizeSpacing.s24),
            PrimaryButton(
              label: l10n.lnkLookUp,
              icon: Icons.search_rounded,
              loading: _busy,
              expand: true,
              onPressed: _field.text.trim().isEmpty
                  ? null
                  : () => unawaited(_lookUp()),
            ),
          ],
        ),
      ),
    );
  }
}
