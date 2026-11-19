import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
// DriftRemoteException is what the shared production isolate throws; the
// library is marked experimental but the class is stable in drift 2.x.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:storize_domain/storize_domain.dart';

/// SQLite's extended result code for `SQLITE_CONSTRAINT_UNIQUE`.
///
/// CHECK (275) and FOREIGN KEY (787) violations have other codes and are left
/// to propagate as they are.
const int sqliteConstraintUnique = 2067;

/// Digs the [SqliteException] out of what drift throws.
///
/// Depending on the executor, drift wraps the original error in a
/// [DriftWrappedException] (local) or a [DriftRemoteException] (the shared
/// isolate used in production).
SqliteException? _sqliteCause(Object error) {
  var current = error;
  for (var depth = 0; depth < 5; depth++) {
    if (current is SqliteException) return current;
    if (current is DriftWrappedException && current.cause != null) {
      current = current.cause!;
    } else if (current is DriftRemoteException) {
      current = current.remoteCause;
    } else {
      return null;
    }
  }
  return null;
}

/// Whether [error] is a UNIQUE constraint violation.
bool isUniqueViolation(Object error) =>
    _sqliteCause(error)?.extendedResultCode == sqliteConstraintUnique;

/// Runs [body] and turns a UNIQUE violation into a [DuplicateEntityException].
Future<T> mapUniqueViolation<T>(
  String entity,
  String key,
  Future<T> Function() body,
) async {
  try {
    return await body();
  } on Object catch (error) {
    if (isUniqueViolation(error)) throw DuplicateEntityException(entity, key);
    rethrow;
  }
}

/// Throws a [StateError] when an update changed no row.
void requireRowChanged(int rows, String what, int id) {
  if (rows == 0) throw StateError('No $what with id $id');
}

/// Encodes a JSON map column; an empty map is stored as NULL.
String? encodeJsonMap(Map<String, Object?> map) =>
    map.isEmpty ? null : jsonEncode(map);

/// Decodes a JSON map column; NULL is an empty map.
Map<String, Object?> decodeJsonMap(String? json) {
  if (json == null) return const {};
  final decoded = jsonDecode(json);
  if (decoded is! Map) {
    throw FormatException('Expected a JSON object', json);
  }
  return Map<String, Object?>.from(decoded);
}

/// Wraps [source] in a new single-subscription stream.
///
/// drift hands out a shared stream for identical queries; the ports promise a
/// new stream per `watchX()` call (UI code listens once per consumer).
Stream<T> freshStream<T>(Stream<T> source) async* {
  yield* source;
}

/// Passes the first event at once, then collapses bursts: after a quiet period
/// of [window] only the latest event is forwarded.
///
/// Used for the library stream, where one download pass updates many rows.
Stream<T> debounceAfterFirst<T>(Stream<T> source, Duration window) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? timer;
  var first = true;
  T? pending;
  var hasPending = false;

  void flush() {
    timer = null;
    if (hasPending) {
      final value = pending as T;
      pending = null;
      hasPending = false;
      controller.add(value);
    }
  }

  controller = StreamController<T>(
    onListen: () {
      subscription = source.listen(
        (value) {
          if (first) {
            first = false;
            controller.add(value);
            return;
          }
          pending = value;
          hasPending = true;
          timer?.cancel();
          timer = Timer(window, flush);
        },
        onError: controller.addError,
        onDone: () {
          timer?.cancel();
          flush();
          unawaited(controller.close());
        },
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () async {
      timer?.cancel();
      timer = null;
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
