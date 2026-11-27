import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// The search text field shown in the S-04 app bar while search is open.
///
/// Calls [onCommit] with the text once the user has stopped typing for
/// [librarySearchDebounce]; submitting or clearing commits at once.
class LibrarySearchField extends StatefulWidget {
  /// Creates the field, starting with [initialText].
  const LibrarySearchField({
    required this.initialText,
    required this.onCommit,
    super.key,
  });

  /// The committed search text when the field opens.
  final String initialText;

  /// Receives the debounced text.
  final ValueChanged<String> onCommit;

  @override
  State<LibrarySearchField> createState() => _LibrarySearchFieldState();
}

class _LibrarySearchFieldState extends State<LibrarySearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(librarySearchDebounce, () => widget.onCommit(text));
  }

  void _commitNow(String text) {
    _debounce?.cancel();
    widget.onCommit(text);
  }

  void _clear() {
    _controller.clear();
    _commitNow('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      key: const ValueKey('library-search-field'),
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _onChanged,
      onSubmitted: _commitNow,
      style: Theme.of(context).textTheme.titleMedium,
      cursorColor: scheme.primary,
      decoration: InputDecoration(
        hintText: l10n.libSearchHint,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('library-search-clear'),
                tooltip: l10n.libSearchClear,
                icon: const Icon(Icons.close_rounded),
                onPressed: _clear,
              ),
      ),
    );
  }
}
