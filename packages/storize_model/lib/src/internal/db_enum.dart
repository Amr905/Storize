/// Internal support for enums that are stored in SQLite columns.
///
/// Not exported from the package barrel.
library;

/// An enum whose value is stored in the database as a SCREAMING_SNAKE string.
abstract interface class DbEnum {
  /// The stable string written to the database column (TECH_SPEC §3).
  String get dbValue;
}

/// Finds the value whose [DbEnum.dbValue] equals [raw].
///
/// Throws an [ArgumentError] when no value matches, so unknown data from the
/// database fails loudly instead of being mapped to a guess.
T decodeDbEnum<T extends DbEnum>(Iterable<T> values, String raw) {
  for (final value in values) {
    if (value.dbValue == raw) return value;
  }
  throw ArgumentError.value(raw, 'raw', 'Unknown $T db value');
}
