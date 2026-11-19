/// Internal helpers for value equality over nested lists and maps.
///
/// Not exported from the package barrel.
library;

/// Structural equality for values that may be lists or maps (recursively).
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

/// Hash code consistent with [deepEquals]. Map entries are unordered.
int deepHash(Object? value) {
  if (value is List) {
    return Object.hashAll(value.map(deepHash));
  }
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map((e) => Object.hash(deepHash(e.key), deepHash(e.value))),
    );
  }
  return value.hashCode;
}

/// Returns a copy of [value] where every nested list and map is unmodifiable.
///
/// A map whose keys are all Strings stays `Map<String, Object?>`, so callers
/// can read JSON-like values with `as Map<String, Object?>`. Other maps keep
/// `Map<Object?, Object?>`.
Object? deepUnmodifiable(Object? value) {
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(deepUnmodifiable));
  }
  if (value is Map) {
    if (value.keys.every((key) => key is String)) {
      return Map<String, Object?>.unmodifiable({
        for (final e in value.entries)
          e.key as String: deepUnmodifiable(e.value),
      });
    }
    return Map<Object?, Object?>.unmodifiable({
      for (final e in value.entries) e.key: deepUnmodifiable(e.value),
    });
  }
  return value;
}
