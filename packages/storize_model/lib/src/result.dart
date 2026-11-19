import 'package:meta/meta.dart';
import 'package:storize_model/src/failure.dart';
import 'package:storize_model/src/internal/deep_equality.dart';

/// The outcome of an operation that can fail: an [Ok] carrying a value, or an
/// [Err] carrying a [Failure]. Errors are values (TECH_SPEC §7).
@immutable
sealed class Result<T> {
  const Result();

  /// True when this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// True when this is an [Err].
  bool get isErr => this is Err<T>;

  /// The value when this is an [Ok], otherwise null.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure when this is an [Err], otherwise null.
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Transforms the value of an [Ok]. An [Err] passes through unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Folds this result into a single value by calling [ok] or [err].
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };
}

/// A successful result holding [value].
@immutable
final class Ok<T> extends Result<T> {
  /// Creates a successful result.
  const Ok(this.value);

  /// The value produced by the operation.
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ok<T> && deepEquals(value, other.value));

  @override
  int get hashCode => Object.hash('Ok', deepHash(value));

  @override
  String toString() => 'Ok($value)';
}

/// A failed result holding [failure].
@immutable
final class Err<T> extends Result<T> {
  /// Creates a failed result.
  const Err(this.failure);

  /// Why the operation failed.
  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T> && other.failure == failure);

  @override
  int get hashCode => Object.hash('Err', failure);

  @override
  String toString() => 'Err($failure)';
}
