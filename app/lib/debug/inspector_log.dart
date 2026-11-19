import 'package:flutter/foundation.dart';
import 'package:storize_app/debug/hook_message.dart';

/// Live, in-memory list of captured responses (never persisted).
class InspectorLog extends ChangeNotifier {
  /// Maximum entries kept; the oldest are dropped.
  static const int maxEntries = 300;

  final List<CapturedResponse> _entries = [];

  /// Newest last.
  List<CapturedResponse> get entries => List.unmodifiable(_entries);

  /// Adds one entry.
  void add(CapturedResponse r) {
    _entries.add(r);
    if (_entries.length > maxEntries) _entries.removeAt(0);
    notifyListeners();
  }

  /// Removes everything.
  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
