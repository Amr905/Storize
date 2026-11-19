import 'package:storize_domain/src/ports/diagnostic_log.dart';

/// One line captured by [FakeDiagnosticLog].
final class FakeLogEntry {
  /// Creates an entry.
  const FakeLogEntry(
    this.level,
    this.tag,
    this.message, {
    this.error,
    this.stack,
  });

  /// The level.
  final LogLevel level;

  /// The component tag.
  final String tag;

  /// The message as given (no redaction in the fake).
  final String message;

  /// The error as given.
  final Object? error;

  /// The stack trace as given.
  final StackTrace? stack;

  @override
  String toString() => '${level.name} [$tag] $message';
}

/// An in-memory [DiagnosticLog] that records entries for assertions.
final class FakeDiagnosticLog implements DiagnosticLog {
  final List<FakeLogEntry> _entries = [];

  /// Everything logged so far, oldest first (unmodifiable view).
  List<FakeLogEntry> get entries => List.unmodifiable(_entries);

  /// Entries at exactly [level].
  List<FakeLogEntry> at(LogLevel level) =>
      _entries.where((e) => e.level == level).toList();

  /// Forgets all entries.
  void clear() => _entries.clear();

  @override
  void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) => _entries.add(
    FakeLogEntry(level, tag, message, error: error, stack: stack),
  );
}
