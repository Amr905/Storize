import 'package:storize_domain/src/ports/clock.dart';

/// A [Clock] that only moves when the test says so.
final class FakeClock implements Clock {
  /// Creates a clock at [start] (UTC), or 2026-01-01T00:00Z by default.
  FakeClock([DateTime? start]) : _now = (start ?? DateTime.utc(2026)).toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) => _now = _now.add(duration);

  /// Sets the clock to [instant], converted to UTC.
  void set(DateTime instant) => _now = instant.toUtc();
}
