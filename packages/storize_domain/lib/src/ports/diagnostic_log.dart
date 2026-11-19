/// How serious a diagnostic log line is.
enum LogLevel {
  /// Fine-grained detail, debug builds only.
  debug,

  /// Normal operation (run start/end, state transitions).
  info,

  /// Something unexpected that the app recovered from.
  warn,

  /// A failure.
  error,
}

/// The diagnostic log (TECH_SPEC §8, ADR-7): a developer-facing, on-device
/// file. It is not the user-facing activity log.
///
/// Implementations must redact secrets (cookies, tokens, signed URLs, PINs)
/// from `message`, `error` and `stack` before anything is stored. Callers
/// should still avoid passing secrets or real people's content.
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class DiagnosticLog {
  /// Records one line.
  ///
  /// [tag] names the component (for example `governor`). [error] and [stack]
  /// are rendered and redacted by the implementation. Never throws.
  void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  });
}
