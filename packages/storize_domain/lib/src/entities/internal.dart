/// Internal helpers shared by the entity classes. Not exported.
library;

/// Marker for "argument not passed" in `copyWith` methods of nullable fields,
/// so that passing an explicit null can clear the field.
const Object unset = _Unset();

final class _Unset {
  const _Unset();
}

/// Picks [value] unless it is [unset], in which case [current] is kept.
T? pick<T>(Object? value, T? current) =>
    identical(value, unset) ? current : value as T?;

/// Structural equality for JSON-like values (nested lists and maps).
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

/// Hash code consistent with [deepEquals].
int deepHash(Object? value) {
  if (value is List) return Object.hashAll(value.map(deepHash));
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map((e) => Object.hash(deepHash(e.key), deepHash(e.value))),
    );
  }
  return value.hashCode;
}

/// Returns an unmodifiable deep copy of a JSON-like map.
Map<String, Object?> freezeMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable({
      for (final e in source.entries) e.key: _freeze(e.value),
    });

Object? _freeze(Object? value) {
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable({
      for (final e in value.entries) e.key: _freeze(e.value),
    });
  }
  return value;
}
