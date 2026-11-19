import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:storize_data/log/redactor.dart';
import 'package:storize_data/log/rotating_log_file.dart';
// TODO(lead): drop once `ports/diagnostic_log.dart` is exported by the barrel.
// ignore: implementation_imports
import 'package:storize_domain/src/ports/diagnostic_log.dart';
import 'package:storize_domain/storize_domain.dart';

/// The diagnostic log (TECH_SPEC §8, ADR-7): redacts each line, then appends
/// it to a [RotatingLogFile], and optionally echoes it to the console.
///
/// Line format: `2026-11-19T06:55:00.000Z INFO [tag] message`, followed by
/// indented `error:` and `stack:` lines when present. Timestamps come from
/// the injected [Clock].
///
/// Line breaks inside the message, error or stack never start a new entry:
/// continuation lines are prefixed with `  | `.
///
/// [log] never throws, and nothing reaches the file or the console before
/// [Redactor.redact] has run over the message, tag, error and stack trace.
final class FileDiagnosticLog implements DiagnosticLog {
  /// Creates a log writing to the given `file`.
  ///
  /// Lines below [minLevel] are dropped. With [console] true each written line
  /// is also sent to `consoleSink` (default: `debugPrint`); use it in debug
  /// builds only.
  FileDiagnosticLog({
    required this._file,
    required this._clock,
    this.minLevel = LogLevel.info,
    this.console = false,
    void Function(String line)? consoleSink,
  }) : _consoleSink = consoleSink ?? _debugPrintLine;

  final RotatingLogFile _file;
  final Clock _clock;
  final void Function(String line) _consoleSink;

  /// The lowest level that is written (INFO in release, DEBUG in debug).
  final LogLevel minLevel;

  /// Whether lines are also echoed to the console.
  final bool console;

  static void _debugPrintLine(String line) => debugPrint(line);

  @override
  void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) {
    if (level.index < minLevel.index) return;
    try {
      final buffer = StringBuffer()
        ..write(_clock.now().toIso8601String())
        ..write(' ')
        ..write(level.name.toUpperCase())
        ..write(' [')
        ..write(Redactor.redact(tag).replaceAll(RegExp(r'\s'), '_'))
        ..write('] ')
        ..write(_indent(Redactor.redact(message)));
      if (error != null) {
        buffer
          ..write('\n  error: ')
          ..write(_indent(Redactor.redact(_describe(error))));
      }
      if (stack != null) {
        buffer
          ..write('\n  stack: ')
          ..write(_indent(Redactor.redact(stack.toString()).trimRight()));
      }
      final line = buffer.toString();
      _file.append(line);
      if (console) _consoleSink(line);
    } on Object {
      // Logging must never throw.
    }
  }

  static final RegExp _lineBreak = RegExp(
    '\r\n|[\n\r\u000B\u000C\u0085\u2028\u2029]',
  );

  /// Turns every line break inside one field into `\n  | `, so injected text
  /// can never start a new entry at column 0 (log forging). Stack traces stay
  /// readable: one frame per continuation line.
  static String _indent(String text) => text.replaceAll(_lineBreak, '\n  | ');

  static String _describe(Object error) {
    try {
      return '${error.runtimeType}: $error';
    } on Object {
      return '${error.runtimeType}: <unprintable>';
    }
  }

  /// Forwards every record of the `logging` package to [log] (TECH_SPEC §8:
  /// the `logging` package feeds the file sink). Records of [Logger.root] and
  /// all children arrive with their logger name as the tag.
  ///
  /// Call `cancel()` on the result to detach. Only one bridge should be
  /// attached per [Logger]; `Logger.root.level` decides what is emitted.
  static void Function() bridgeLogging(DiagnosticLog log, {Logger? root}) {
    final logger = root ?? Logger.root;
    final sub = logger.onRecord.listen((r) {
      log.log(
        _map(r.level),
        r.loggerName,
        r.message,
        error: r.error,
        stack: r.stackTrace,
      );
    });
    return sub.cancel;
  }

  static LogLevel _map(Level level) {
    if (level >= Level.SEVERE) return LogLevel.error;
    if (level >= Level.WARNING) return LogLevel.warn;
    if (level >= Level.INFO) return LogLevel.info;
    return LogLevel.debug;
  }
}
