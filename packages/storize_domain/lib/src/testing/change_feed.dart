import 'dart:async';

/// Turns "something changed" signals into watch streams for the fakes.
///
/// Not exported. Each fake owns one feed and calls [notify] after a mutation.
final class ChangeFeed {
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  /// Tells every open watch stream to re-read its value.
  void notify() => _changes.add(null);

  /// A single-subscription stream that emits `read()` on listen and again after
  /// every [notify].
  Stream<T> watch<T>(T Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        subscription = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}
