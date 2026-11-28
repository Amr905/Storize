import 'dart:async';

import 'package:flutter/services.dart';

/// Name of the channel that carries text shared into the app (FR-80).
const String storizeShareInChannelName = 'storize/share_in';

/// The channel of [ShareIntentSource].
const MethodChannel storizeShareInChannel = MethodChannel(
  storizeShareInChannelName,
);

/// Text shared into Storize with "Share -> Storize" (Android `ACTION_SEND`,
/// `text/plain`, FR-80).
///
/// [initialText] is the text that launched the app (read once). [texts]
/// emits text shared while the app runs. The text is a link the user chose
/// to share: do not log it.
class ShareIntentSource {
  /// Creates the source over [channel] (the real channel by default).
  ShareIntentSource({MethodChannel? channel})
    : _channel = channel ?? storizeShareInChannel;

  final MethodChannel _channel;
  StreamController<String>? _controller;

  /// The text that launched the app, or null. Asking again gives null.
  /// Never throws: no plugin (tests, other platforms) is "no text".
  Future<String?> initialText() async {
    try {
      final text = await _channel.invokeMethod<String>('initialText');
      return text == null || text.trim().isEmpty ? null : text;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Text shared while the app runs (a broadcast stream). The first listener
  /// starts listening to the channel.
  Stream<String> get texts {
    final existing = _controller;
    if (existing != null) return existing.stream;
    final controller = StreamController<String>.broadcast();
    _controller = controller;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onText') {
        final text = call.arguments;
        if (text is String && text.trim().isNotEmpty) controller.add(text);
      }
      return null;
    });
    return controller.stream;
  }
}
