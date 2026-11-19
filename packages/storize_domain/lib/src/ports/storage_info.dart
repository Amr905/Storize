/// Reports the free and total space of the device storage that holds the
/// gallery.
///
/// Implementations may throw when the platform cannot answer. Callers treat
/// that as "unknown" and do not stop downloads because of it.
abstract interface class StorageInfo {
  /// Bytes currently free on the gallery volume.
  Future<int> freeBytes();

  /// Total bytes of the gallery volume.
  Future<int> totalBytes();
}

/// Free-space thresholds for downloads (NFR-13).
abstract final class StoragePolicy {
  /// Below this much free space (1 GiB) a `STORAGE_LOW` event is raised
  /// (NFR-13).
  static const int lowSpaceBytes = 1024 * 1024 * 1024;

  /// Below this much free space (200 MiB) downloads stop and a
  /// `STORAGE_PAUSED` event is raised (NFR-13).
  static const int pauseBytes = 200 * 1024 * 1024;
}
