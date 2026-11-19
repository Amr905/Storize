import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why a screen has nothing to show.
enum EmptyReason {
  /// There is no data yet.
  noData,

  /// Data exists but the active filters hide all of it.
  filteredOut,
}

/// What kind of failure an error state reports.
enum UiErrorKind {
  /// No connection.
  network,

  /// Instagram is limiting requests.
  rateLimited,

  /// Instagram changed and Storize needs an update.
  platformChanged,

  /// Anything else.
  unknown,
}

/// What a screen shows: loading, content, empty or error.
///
/// Maps 1:1 to the state tables in UX.md (TECH_SPEC section 7).
///
/// ## Guideline
///
/// Call `repo.watchX()` **once per provider**. Repository streams are
/// single-subscription: never hand one stream object to several listeners.
/// Wrap it in a provider (`StreamProvider`) and let widgets watch the
/// provider. Convert the provider's `AsyncValue` with
/// [AsyncValueUiState.toUiState] and render it with `UiStateView`.
@immutable
sealed class UiState<T> {
  const UiState();
}

/// Data is loading.
final class UiLoading<T> extends UiState<T> {
  /// Creates a loading state.
  const UiLoading();

  @override
  bool operator ==(Object other) => other is UiLoading<T>;

  @override
  int get hashCode => (UiLoading<T>).hashCode;
}

/// Data is available.
final class UiContent<T> extends UiState<T> {
  /// Creates a content state.
  const UiContent(this.value);

  /// The data.
  final T value;

  @override
  bool operator ==(Object other) =>
      other is UiContent<T> && other.value == value;

  @override
  int get hashCode => Object.hash(UiContent, value);
}

/// There is nothing to show.
final class UiEmpty<T> extends UiState<T> {
  /// Creates an empty state.
  const UiEmpty(this.reason);

  /// Why it is empty.
  final EmptyReason reason;

  @override
  bool operator ==(Object other) =>
      other is UiEmpty<T> && other.reason == reason;

  @override
  int get hashCode => Object.hash(UiEmpty, reason);
}

/// Loading failed.
final class UiError<T> extends UiState<T> {
  /// Creates an error state. [retry] is shown as the Retry button.
  const UiError(this.kind, {this.retry});

  /// The kind of failure.
  final UiErrorKind kind;

  /// Called when the user taps Retry. No button when null.
  final VoidCallback? retry;

  @override
  bool operator ==(Object other) =>
      other is UiError<T> && other.kind == kind && other.retry == retry;

  @override
  int get hashCode => Object.hash(UiError, kind, retry);
}

/// Converts a Riverpod [AsyncValue] to a [UiState].
extension AsyncValueUiState<T> on AsyncValue<T> {
  /// Maps this value.
  ///
  /// - has a value: [UiContent], or [UiEmpty] when [isEmpty] says so (a
  ///   refresh in progress or a failed refresh keeps the old value visible);
  /// - error without a value: [UiError] with [errorKind] (default unknown)
  ///   and [retry];
  /// - otherwise: [UiLoading].
  UiState<T> toUiState({
    bool Function(T value)? isEmpty,
    EmptyReason emptyReason = EmptyReason.noData,
    UiErrorKind Function(Object error)? errorKind,
    VoidCallback? retry,
  }) {
    if (hasValue) {
      final v = requireValue;
      if (isEmpty != null && isEmpty(v)) return UiEmpty<T>(emptyReason);
      return UiContent<T>(v);
    }
    if (hasError) {
      final e = error!;
      return UiError<T>(
        errorKind?.call(e) ?? UiErrorKind.unknown,
        retry: retry,
      );
    }
    return UiLoading<T>();
  }
}
