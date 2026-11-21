import 'package:meta/meta.dart';
import 'package:storize_domain/src/ports/storage_info.dart';
import 'package:storize_domain/src/repos/content_repo.dart';

/// Storage usage for the storage screens (FR-53).
@immutable
final class StorageReport {
  /// Creates a report. [bytesByTarget] is copied and made unmodifiable.
  StorageReport({
    required Map<int, int> bytesByTarget,
    this.freeBytes,
    this.deviceTotalBytes,
  }) : bytesByTarget = Map<int, int>.unmodifiable(bytesByTarget);

  /// Stored media bytes per target ID. Targets without files are absent.
  final Map<int, int> bytesByTarget;

  /// Free bytes on the gallery volume, or null when unknown. Never more than
  /// [deviceTotalBytes].
  final int? freeBytes;

  /// Total bytes of the gallery volume, or null when unknown.
  final int? deviceTotalBytes;

  /// The sum of [bytesByTarget] over all targets.
  int get totalBytes => bytesByTarget.values.fold(0, (a, b) => a + b);

  @override
  String toString() =>
      'StorageReport(totalBytes: $totalBytes, freeBytes: $freeBytes, '
      'deviceTotalBytes: $deviceTotalBytes)';
}

/// Computes storage usage per target and on the device (FR-53, NFR-13).
///
/// Per-target totals come from [ContentRepo.storageBytesByTarget], which sums
/// the stored `size_bytes` of downloaded files. Device space comes from
/// [StorageInfo]. A throw or a negative value from it means "unknown" (null).
/// It never fails the call, so a broken storage query does not stop the
/// screen. Free space is clamped to at most the device total.
final class ComputeStorage {
  /// Creates the use case.
  ComputeStorage({required this.content, required this.storage});

  /// Stored content, for the per-target sums.
  final ContentRepo content;

  /// Device space, for free and total bytes.
  final StorageInfo storage;

  /// Builds the report.
  Future<StorageReport> call() async {
    final bytes = await content.storageBytesByTarget();
    final total = await _read(storage.totalBytes);
    var free = await _read(storage.freeBytes);
    if (free != null && total != null && free > total) free = total;
    return StorageReport(
      bytesByTarget: bytes,
      freeBytes: free,
      deviceTotalBytes: total,
    );
  }

  /// Reads one value. Any error or a negative value is null (unknown).
  static Future<int?> _read(Future<int> Function() read) async {
    try {
      final value = await read();
      return value < 0 ? null : value;
    } on Object {
      return null;
    }
  }
}
