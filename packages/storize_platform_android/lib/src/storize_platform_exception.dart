import 'package:flutter/services.dart';

/// Error categories the native plugin reports.
enum StorizePlatformErrorKind {
  invalidArgument('INVALID_ARGUMENT'),
  unsupportedMime('UNSUPPORTED_MIME'),
  sourceNotFound('SOURCE_NOT_FOUND'),
  permissionDenied('PERMISSION_DENIED'),
  storageFull('STORAGE_FULL'),
  ioError('IO_ERROR'),
  insertFailed('INSERT_FAILED'),
  thumbnailFailed('THUMBNAIL_FAILED'),

  /// The native side is missing or detached (also used for
  /// `MissingPluginException`).
  unavailable('UNAVAILABLE'),

  /// The native side answered with something we cannot decode.
  badResponse('BAD_RESPONSE'),
  unknown('UNKNOWN');

  const StorizePlatformErrorKind(this.code);

  /// The code string sent by the native plugin.
  final String code;

  /// Maps a native code to its kind. Unrecognised codes become [unknown].
  static StorizePlatformErrorKind fromCode(String code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return unknown;
  }
}

/// A failure reported by the native plugin.
class StorizePlatformException implements Exception {
  const StorizePlatformException(this.code, [this.message]);

  /// Wraps a [PlatformException] without losing its code.
  factory StorizePlatformException.fromPlatform(PlatformException e) =>
      StorizePlatformException(e.code, e.message);

  /// The raw native code, for example `UNSUPPORTED_MIME`.
  final String code;

  /// Human-readable detail from the native side (never contains secrets).
  final String? message;

  /// The code as a typed category.
  StorizePlatformErrorKind get kind => StorizePlatformErrorKind.fromCode(code);

  @override
  String toString() => 'StorizePlatformException($code: $message)';
}
