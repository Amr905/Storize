import 'package:storize_model/storize_model.dart';

/// Thrown when a response lacks something the mappers need. [where] is a
/// field path such as `data.user.username`: names only, never values.
final class SchemaException implements Exception {
  /// Creates the exception for the field path [where].
  const SchemaException(this.where);

  /// The field path.
  final String where;

  /// The equivalent failure.
  SchemaChanged toFailure() => SchemaChanged(where);

  @override
  String toString() => 'SchemaException($where)';
}

/// Runs [body] and turns a [SchemaException] into `Err(SchemaChanged)`.
Result<T> guardMapping<T>(T Function() body) {
  try {
    return Ok<T>(body());
  } on SchemaException catch (e) {
    return Err<T>(e.toFailure());
  }
}

/// A JSON value plus its path, so a missing field reports where it was.
///
/// Reading is tolerant: unknown keys are never looked at. A required accessor
/// throws [SchemaException] with the path when the value is missing or has the
/// wrong type. An optional accessor returns null instead.
final class Node {
  /// Wraps [value], reported as [path].
  const Node(this.value, this.path);

  /// The root of a response, named [name] in paths.
  factory Node.root(Object? value, String name) => Node(value, name);

  /// The raw JSON value.
  final Object? value;

  /// The field path, for example `items[0].taken_at`.
  final String path;

  /// True for a missing key or JSON null.
  bool get isNull => value == null;

  /// The child at [key]. A non-map parent gives a null child.
  Node operator [](String key) {
    final v = value;
    return Node(v is Map<String, Object?> ? v[key] : null, '$path.$key');
  }

  /// Whether this is an object that has the key [key] (even with null).
  bool has(String key) {
    final v = value;
    return v is Map<String, Object?> && v.containsKey(key);
  }

  /// Required object.
  Map<String, Object?> get map {
    final v = value;
    if (v is Map<String, Object?>) return v;
    throw SchemaException(path);
  }

  /// Object or null (a wrong type is a [SchemaException]).
  Map<String, Object?>? get mapOrNull => isNull ? null : map;

  /// Required list, as nodes.
  List<Node> get list {
    final v = value;
    if (v is! List<Object?>) throw SchemaException(path);
    return [for (var i = 0; i < v.length; i++) Node(v[i], '$path[$i]')];
  }

  /// List or an empty list when missing or null.
  List<Node> get listOrEmpty => isNull ? const [] : list;

  /// Required non-empty string. Integers are accepted and converted, because
  /// ids are sometimes numbers.
  String get string {
    final s = stringOrNull;
    if (s == null || s.isEmpty) throw SchemaException(path);
    return s;
  }

  /// String (or integer as string) or null.
  String? get stringOrNull {
    final v = value;
    if (v == null) return null;
    if (v is String) return v;
    if (v is int) return v.toString();
    throw SchemaException(path);
  }

  /// Required whole number (a double without a fraction is accepted).
  int get integer {
    final i = intOrNull;
    if (i == null) throw SchemaException(path);
    return i;
  }

  /// Whole number or null.
  int? get intOrNull {
    final v = value;
    if (v == null) return null;
    if (v is int) return v;
    if (v is double && v == v.truncateToDouble()) return v.toInt();
    throw SchemaException(path);
  }

  /// Number (int or double) or null.
  num? get numOrNull {
    final v = value;
    if (v == null) return null;
    if (v is num) return v;
    throw SchemaException(path);
  }

  /// Bool or null. Numbers 0 and 1 count as bools.
  bool? get boolOrNull {
    final v = value;
    if (v == null) return null;
    if (v is bool) return v;
    if (v is int && (v == 0 || v == 1)) return v == 1;
    throw SchemaException(path);
  }

  /// Unix seconds as a UTC time (required).
  DateTime get unixTime => _fromUnix(integer);

  /// Unix seconds as a UTC time, or null when missing or not positive.
  DateTime? get unixTimeOrNull {
    final i = intOrNull;
    return i == null || i <= 0 ? null : _fromUnix(i);
  }

  static DateTime _fromUnix(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}
