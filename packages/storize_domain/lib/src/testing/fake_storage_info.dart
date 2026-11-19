import 'package:storize_domain/src/ports/storage_info.dart';

/// A [StorageInfo] whose values the test sets.
final class FakeStorageInfo implements StorageInfo {
  /// Creates the fake with 10 GiB free of 64 GiB by default.
  FakeStorageInfo({
    this.free = 10 * 1024 * 1024 * 1024,
    this.total = 64 * 1024 * 1024 * 1024,
  });

  /// The value returned by `freeBytes`. Change it between calls.
  int free;

  /// The value returned by `totalBytes`.
  int total;

  @override
  Future<int> freeBytes() async => free;

  @override
  Future<int> totalBytes() async => total;
}
