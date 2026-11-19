import 'package:storize_domain/storize_domain.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

/// [StorageInfo] over the native plugin: free and total bytes of the primary
/// shared storage, the volume that holds the gallery (NFR-13).
///
/// A native failure surfaces as a [StorizePlatformException]. Callers treat it
/// as "unknown" and must not stop downloads because of it.
final class PluginStorageInfo implements StorageInfo {
  /// Creates the reader over the native plugin API.
  PluginStorageInfo(this._plugin);

  final StorizePlatformAndroid _plugin;

  @override
  Future<int> freeBytes() async => (await _plugin.storageStats()).freeBytes;

  @override
  Future<int> totalBytes() async => (await _plugin.storageStats()).totalBytes;
}
