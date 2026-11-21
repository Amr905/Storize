import 'package:flutter/services.dart';
import 'package:storize_platform_android/src/models.dart';
import 'package:storize_platform_android/src/storize_platform_exception.dart';

/// Name of the media channel (gallery operations).
const String storizeMediaChannelName = 'storize/media';

/// Name of the system channel (battery, OEM screens, stop reasons).
const String storizeSystemChannelName = 'storize/system';

/// The gallery channel.
const MethodChannel storizeMediaChannel = MethodChannel(
  storizeMediaChannelName,
);

/// The system channel.
const MethodChannel storizeSystemChannel = MethodChannel(
  storizeSystemChannelName,
);

/// Thin typed wrapper over the two native channels (ADR-11).
///
/// It has no domain dependencies: `GalleryStore` adapts it in T-010. Every
/// native failure surfaces as a [StorizePlatformException].
class StorizePlatformAndroid {
  StorizePlatformAndroid({MethodChannel? media, MethodChannel? system})
    : _media = media ?? storizeMediaChannel,
      _system = system ?? storizeSystemChannel;

  final MethodChannel _media;
  final MethodChannel _system;

  /// Copies [sourcePath] into `Pictures/Storize/<relativeDir>/<displayName>`.
  Future<InsertedMedia> insert({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) async {
    final map = await _call<Map<Object?, Object?>>(_media, 'insert', {
      'sourcePath': sourcePath,
      'relativeDir': relativeDir,
      'displayName': displayName,
      'mime': mime,
    });
    final uri = map?['uri'];
    final size = map?['size'];
    final relativePath = map?['relativePath'];
    final finalName = map?['displayName'];
    if (uri is! String || size is! int) {
      throw _bad('insert', map);
    }
    return InsertedMedia(
      uri: uri,
      size: size,
      displayName: finalName is String ? finalName : displayName,
      relativePath: relativePath is String ? relativePath : null,
    );
  }

  /// Deletes the file. False if it was already gone. No system prompt for
  /// files the app owns. A file outside `Storize/` is refused with
  /// `PERMISSION_DENIED`.
  Future<bool> delete(String uri) async => _requireBool(
    'delete',
    await _call<Object?>(_media, 'delete', {'uri': uri}),
  );

  /// Whether the file is still there (false for files outside `Storize/`).
  Future<bool> exists(String uri) async => _requireBool(
    'exists',
    await _call<Object?>(_media, 'exists', {'uri': uri}),
  );

  /// Size in bytes, or null if the file is missing.
  Future<int?> size(String uri) async {
    final value = await _call<Object?>(_media, 'size', {'uri': uri});
    if (value == null) return null;
    if (value is int) return value;
    throw _bad('size', value);
  }

  /// Finds a finished file this app saved under `Storize/<relativeDir>/` with
  /// exactly [displayName], or null. Only files the app owns are returned.
  /// Used to adopt a file saved just before a kill (NFR-7).
  Future<InsertedMedia?> findByName({
    required String relativeDir,
    required String displayName,
  }) async {
    final map = await _call<Map<Object?, Object?>>(_media, 'findByName', {
      'relativeDir': relativeDir,
      'displayName': displayName,
    });
    if (map == null) return null;
    final uri = map['uri'];
    final size = map['size'];
    final relativePath = map['relativePath'];
    final name = map['displayName'];
    if (uri is! String || size is! int) throw _bad('findByName', map);
    return InsertedMedia(
      uri: uri,
      size: size,
      displayName: name is String ? name : displayName,
      relativePath: relativePath is String ? relativePath : null,
    );
  }

  /// Free and total bytes of the primary shared storage (the gallery volume).
  Future<StorageStats> storageStats() async {
    final raw = await _call<Object?>(_media, 'storageStats');
    if (raw is! Map) throw _bad('storageStats', raw);
    final free = raw['freeBytes'];
    final total = raw['totalBytes'];
    if (free is! int || total is! int || free < 0 || total <= 0) {
      throw _bad('storageStats', raw);
    }
    return StorageStats(freeBytes: free, totalBytes: total);
  }

  /// A WEBP frame of a video, scaled so the longer side is at most [maxSize].
  /// Pass exactly one of [uri] or [path].
  Future<Uint8List> videoThumbnail({
    String? uri,
    String? path,
    int maxSize = 512,
  }) async {
    if ((uri == null) == (path == null)) {
      throw ArgumentError('Pass exactly one of uri or path');
    }
    final bytes = await _call<Uint8List>(_media, 'videoThumbnail', {
      'uri': ?uri,
      'path': ?path,
      'maxSize': maxSize,
    });
    if (bytes == null) throw _bad('videoThumbnail', bytes);
    return bytes;
  }

  /// Whether the app is exempt from battery optimization.
  Future<bool> isIgnoringBatteryOptimizations() async => _requireBool(
    'isIgnoringBatteryOptimizations',
    await _call<bool>(_system, 'isIgnoringBatteryOptimizations'),
  );

  /// Opens the best battery screen: the exemption request, then the OEM
  /// screen, then app details. [oem] defaults to this device's manufacturer.
  Future<BatterySettingsOutcome> openBatterySettings({String? oem}) async {
    final raw = await _call<String>(_system, 'openBatterySettings', {
      'oem': ?oem,
    });
    return BatterySettingsOutcome.parse(raw);
  }

  /// Normalised manufacturer: `samsung`, `xiaomi`, `oppo` (also Realme),
  /// `vivo`, `huawei` or `other`.
  Future<String> manufacturer() async {
    final value = await _call<String>(_system, 'manufacturer');
    if (value == null) throw _bad('manufacturer', value);
    return value;
  }

  /// Recent reasons the app's process was stopped (Android 11+, empty below).
  Future<List<StopReason>> lastStopReasons({int limit = 10}) async {
    final list = await _call<List<Object?>>(_system, 'lastStopReasons', {
      'limit': limit,
    });
    if (list == null) throw _bad('lastStopReasons', list);
    return [
      for (final item in list)
        if (item is Map &&
            item['workName'] is String &&
            item['reason'] is String)
          StopReason(
            workName: item['workName']! as String,
            reason: item['reason']! as String,
            timestampMs: item['timestampMs'] is int
                ? item['timestampMs']! as int
                : null,
          )
        else
          throw _bad('lastStopReasons', item),
    ];
  }

  Future<T?> _call<T>(
    MethodChannel channel,
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw StorizePlatformException.fromPlatform(e);
    } on MissingPluginException catch (e) {
      throw StorizePlatformException(
        StorizePlatformErrorKind.unavailable.code,
        e.message,
      );
    }
  }

  bool _requireBool(String method, Object? value) =>
      value is bool ? value : throw _bad(method, value);

  StorizePlatformException _bad(String method, Object? value) =>
      StorizePlatformException(
        StorizePlatformErrorKind.badResponse.code,
        'Unexpected $method result type: ${value.runtimeType}',
      );
}
