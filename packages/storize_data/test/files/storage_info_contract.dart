import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';

/// A [StorageInfo] plus a way to set the numbers it reports.
class StorageInfoHarness {
  StorageInfoHarness({required this.info, required this.set});
  final StorageInfo info;
  final void Function({required int free, required int total}) set;
}

/// Shared behaviour of every `StorageInfo`: real and fake.
void storageInfoContract(
  String label,
  Future<StorageInfoHarness> Function() create,
) {
  group('StorageInfo contract: $label', () {
    late StorageInfoHarness h;
    setUp(() async => h = await create());

    test('reports the free and total bytes', () async {
      h.set(free: 5, total: 10);
      expect(await h.info.freeBytes(), 5);
      expect(await h.info.totalBytes(), 10);
    });

    test('follows changes between calls', () async {
      h.set(free: 5, total: 10);
      expect(await h.info.freeBytes(), 5);
      h.set(free: 1, total: 10);
      expect(await h.info.freeBytes(), 1);
    });

    test('handles values above 32 bits', () async {
      const big = 2 * 1024 * 1024 * 1024 * 1024;
      h.set(free: big ~/ 4, total: big);
      expect(await h.info.freeBytes(), big ~/ 4);
      expect(await h.info.totalBytes(), big);
    });

    test('zero free is valid and below the pause threshold', () async {
      h.set(free: 0, total: 10);
      expect(await h.info.freeBytes(), 0);
      expect(await h.info.freeBytes(), lessThan(StoragePolicy.pauseBytes));
    });
  });
}
