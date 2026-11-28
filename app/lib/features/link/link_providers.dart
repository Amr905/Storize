import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_domain/storize_domain.dart';

/// The use case behind "Save from link" (FR-80). Wired by the composition
/// root.
final saveFromLinkProvider = Provider<SaveFromLink>(
  (ref) => throw UnimplementedError('saveFromLinkProvider is not wired'),
);

/// Reads the text on the clipboard, or null when there is none. Tests
/// override it; the default asks the system.
typedef ClipboardTextReader = Future<String?> Function();

/// The clipboard reader.
final clipboardTextReaderProvider = Provider<ClipboardTextReader>(
  (ref) => () async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } on PlatformException {
      return null;
    }
  },
);

/// The clipboard text when it holds an Instagram link, else null.
Future<String?> clipboardInstagramText(ClipboardTextReader read) async {
  try {
    final text = await read();
    if (text == null || text.length > 4096) return null;
    return LinkParser.containsInstagramLink(text) ? text.trim() : null;
  } on Object {
    return null;
  }
}

/// Text shared into the app while it runs ("Share -> Storize"). `main`
/// overrides it with the platform stream; the root widget opens Save from
/// link for each text. A cold start uses `initialLocation` instead.
final sharedTextProvider = StreamProvider<String>(
  (ref) => const Stream<String>.empty(),
);

/// The clipboard text that was already offered or handled, so the resume
/// offer shows once per copied link (in memory only).
class HandledClipboardText extends Notifier<String?> {
  @override
  String? build() => null;

  /// Remembers [text].
  // ignore: use_setters_to_change_properties, a notifier command.
  void mark(String? text) => state = text;
}

/// The last copied text that was offered or opened.
final handledClipboardTextProvider =
    NotifierProvider<HandledClipboardText, String?>(HandledClipboardText.new);
