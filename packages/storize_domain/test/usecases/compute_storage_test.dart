import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

/// A [StorageInfo] that throws on the chosen calls.
final class ThrowingStorage implements StorageInfo {
  ThrowingStorage({this.throwFree = false, this.throwTotal = false});

  final bool throwFree;
  final bool throwTotal;

  @override
  Future<int> freeBytes() async {
    if (throwFree) throw StateError('no free-space API');
    return 5;
  }

  @override
  Future<int> totalBytes() async {
    if (throwTotal) throw StateError('no total-space API');
    return 100;
  }
}

void main() {
  late FakeTargetRepo targets;
  late FakeContentRepo content;
  late Target t1;
  late Target t2;

  Future<void> addDone(Target t, String remoteId, int size) async {
    await content.insertIfNew(
      s.content(targetId: t.id, remoteId: remoteId),
      [s.media(status: MediaFileStatus.done, sizeBytes: size)],
    );
  }

  setUp(() async {
    targets = FakeTargetRepo();
    content = FakeContentRepo(targets: targets);
    t1 = await targets.insert(s.target());
    t2 = await targets.insert(s.target(remoteUserId: '200', username: 'bob'));
  });

  test('sums size_bytes per target and in total', () async {
    await addDone(t1, 'a', 300);
    await addDone(t1, 'b', 200);
    await addDone(t2, 'c', 50);

    final report = await ComputeStorage(
      content: content,
      storage: FakeStorageInfo(free: 1000, total: 4000),
    ).call();

    expect(report.bytesByTarget, {t1.id: 500, t2.id: 50});
    expect(report.totalBytes, 550);
  });

  test('pending media and targets without files are not counted', () async {
    await content.insertIfNew(
      s.content(targetId: t1.id, remoteId: 'p'),
      [s.media(sizeBytes: 999)],
    );
    final report = await ComputeStorage(
      content: content,
      storage: FakeStorageInfo(),
    ).call();
    expect(report.bytesByTarget, isEmpty);
    expect(report.totalBytes, 0);
  });

  test('reports device free and total space', () async {
    final report = await ComputeStorage(
      content: content,
      storage: FakeStorageInfo(free: 10, total: 100),
    ).call();
    expect(report.freeBytes, 10);
    expect(report.deviceTotalBytes, 100);
  });

  test('free space above the total is clamped to the total', () async {
    final report = await ComputeStorage(
      content: content,
      storage: FakeStorageInfo(free: 500, total: 100),
    ).call();
    expect(report.freeBytes, 100);
    expect(report.deviceTotalBytes, 100);
  });

  test(
    'a throwing freeBytes means unknown (null), total still reported',
    () async {
      final report = await ComputeStorage(
        content: content,
        storage: ThrowingStorage(throwFree: true),
      ).call();
      expect(report.freeBytes, isNull);
      expect(report.deviceTotalBytes, 100);
    },
  );

  test(
    'a throwing totalBytes means unknown; free is then not clamped',
    () async {
      final report = await ComputeStorage(
        content: content,
        storage: ThrowingStorage(throwTotal: true),
      ).call();
      expect(report.deviceTotalBytes, isNull);
      expect(report.freeBytes, 5);
    },
  );

  test('both storage reads throwing still returns a report', () async {
    final report = await ComputeStorage(
      content: content,
      storage: ThrowingStorage(throwFree: true, throwTotal: true),
    ).call();
    expect(report.freeBytes, isNull);
    expect(report.deviceTotalBytes, isNull);
    expect(report.totalBytes, 0);
  });

  test('a negative reading is treated as unknown', () async {
    final report = await ComputeStorage(
      content: content,
      storage: FakeStorageInfo(free: -1, total: 100),
    ).call();
    expect(report.freeBytes, isNull);
    expect(report.deviceTotalBytes, 100);
  });

  test('the per-target map is unmodifiable', () async {
    final report = await ComputeStorage(
      content: content,
      storage: FakeStorageInfo(),
    ).call();
    expect(
      () => report.bytesByTarget[1] = 1,
      throwsUnsupportedError,
    );
  });
}
