import 'package:meta/meta.dart';

/// Base type for failures that ports report by throwing instead of returning
/// a `Result`.
///
/// `Failure` in `storize_model` is sealed and describes Instagram-facing
/// problems, so local problems (storage, validation) use exceptions.
@immutable
sealed class DomainException implements Exception {
  const DomainException();
}

/// Thrown by a repository when an insert violates a UNIQUE constraint.
///
/// For targets this is EC-16 (same platform and remote user ID twice).
@immutable
final class DuplicateEntityException extends DomainException {
  /// Creates the exception. [entity] names the table, [key] the unique key.
  const DuplicateEntityException(this.entity, this.key);

  /// The entity type, for example `target`.
  final String entity;

  /// A short description of the violated key. Never contains secrets.
  final String key;

  @override
  String toString() => 'DuplicateEntityException($entity, $key)';
}

/// Thrown by `SettingsRepo.update` when the new settings break a rule.
///
/// Nothing is stored when this is thrown.
@immutable
final class SettingsValidationException extends DomainException {
  /// Creates the exception with the list of [problems].
  SettingsValidationException(List<String> problems)
    : problems = List<String>.unmodifiable(problems);

  /// One human-readable message per invalid setting. Never empty.
  final List<String> problems;

  @override
  String toString() => 'SettingsValidationException($problems)';
}

/// Why `ContentPlatform.openMedia` could not deliver a file.
///
/// `openMedia` returns a `Stream`, so it reports these by emitting the
/// exception as a stream error (not by throwing synchronously).
@immutable
sealed class MediaStreamException extends DomainException {
  const MediaStreamException();
}

/// The CDN rejected the signed URL (HTTP 403) because it expired.
///
/// The caller should refresh the URL once through the platform (FR-25) and
/// retry. Bytes emitted before the error are valid, so a resume with
/// `fromByte` is allowed.
@immutable
final class ExpiredMediaUrl extends MediaStreamException {
  /// Creates the exception.
  const ExpiredMediaUrl();

  @override
  String toString() => 'ExpiredMediaUrl()';
}

/// Any other transfer failure: socket error, timeout or an HTTP error that is
/// not an expired URL.
@immutable
final class MediaStreamFailure extends MediaStreamException {
  /// Creates the exception. [statusCode] is null for non-HTTP errors.
  const MediaStreamFailure({this.statusCode, this.message});

  /// The HTTP status code, when there was a response.
  final int? statusCode;

  /// A short diagnostic message. Must not contain URLs or other secrets.
  final String? message;

  @override
  String toString() =>
      'MediaStreamFailure(statusCode: $statusCode, message: $message)';
}

/// Why `GalleryStore` could not save or delete a file.
///
/// It extends the sealed [DomainException] family, so a `switch` over
/// [GalleryStoreException] is exhaustive over its three subtypes. None of them
/// carries a path, URI or file name: only a native error [code].
@immutable
sealed class GalleryStoreException extends DomainException {
  /// Creates the exception with the native [code].
  const GalleryStoreException(this.code);

  /// The native error code, for example `PERMISSION_DENIED`.
  final String code;
}

/// The gallery refused the operation (`PERMISSION_DENIED`).
///
/// On Android 8-9 (API <= 28) the caller should ask for the runtime permission
/// `WRITE_EXTERNAL_STORAGE` (S-03 card) and retry. On a delete it means the
/// row is not owned by Storize (for example after a reinstall).
@immutable
final class GalleryPermissionDenied extends GalleryStoreException {
  /// Creates the exception.
  const GalleryPermissionDenied() : super('PERMISSION_DENIED');

  @override
  String toString() => 'GalleryPermissionDenied()';
}

/// The device has no space left for the file (`STORAGE_FULL`).
@immutable
final class GalleryStorageFull extends GalleryStoreException {
  /// Creates the exception.
  const GalleryStorageFull() : super('STORAGE_FULL');

  @override
  String toString() => 'GalleryStorageFull()';
}

/// Any other gallery failure. Only the [code] is kept, so the message cannot
/// leak a path.
@immutable
final class GalleryWriteFailed extends GalleryStoreException {
  /// Creates the exception with the native [code].
  const GalleryWriteFailed(super.code);

  @override
  String toString() => 'GalleryWriteFailed($code)';
}
