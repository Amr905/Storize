/// A source of the current time. Injected so tests control it (EC-18).
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class Clock {
  /// The current instant as a UTC [DateTime] (`isUtc` is true).
  DateTime now();
}

/// The real clock, backed by `DateTime.now()`.
final class SystemClock implements Clock {
  /// Creates the system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
