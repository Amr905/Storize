import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart';

void main() {
  test('FakeTargetRepo.update onto a taken key is a duplicate', () async {
    final repo = FakeTargetRepo();
    await repo.insert(target(remoteUserId: '1'));
    final b = await repo.insert(target(remoteUserId: '2', username: 'bob'));
    final clash = Target(
      id: b.id,
      platform: PlatformId.instagram,
      remoteUserId: '1',
      username: 'bob',
      category: TargetCategory.public,
      postsWatermarkAt: t0,
      addedAt: t0,
    );
    await expectLater(
      repo.update(clash),
      throwsA(isA<DuplicateEntityException>()),
    );
    expect((await repo.getById(b.id))!.remoteUserId, '2');
    await repo.update(b.copyWith(username: 'same-key'));
  });

  test('FakeContentRepo: update duplicate and cascade notification', () async {
    final targets = FakeTargetRepo();
    final repo = FakeContentRepo(targets: targets);
    final t = await targets.insert(target(remoteUserId: '1'));
    final a = await repo.insertIfNew(
      content(targetId: t.id, remoteId: 'a'),
      const [],
    );
    await repo.insertIfNew(content(targetId: t.id, remoteId: 'b'), const []);
    final clash = Content(
      id: a.contentId,
      targetId: t.id,
      kind: ContentKind.story,
      remoteId: 'b',
      postedAt: t0,
      slideCount: 1,
      detectedAt: t0,
    );
    await expectLater(
      repo.updateContent(clash),
      throwsA(isA<DuplicateEntityException>()),
    );

    final emissions = <int>[];
    final sub = repo
        .watchLibrary(ContentFilter())
        .listen((l) => emissions.add(l.length));
    await Future<void>.delayed(Duration.zero);
    await targets.delete(t.id);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emissions, [2, 0]);
  });
}
