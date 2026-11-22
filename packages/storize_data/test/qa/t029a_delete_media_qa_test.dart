import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';

import '../repo/support/builders.dart';
import '../repo/support/harness.dart';

void main() {
  late DriftHarness h;
  late ContentRepo repo;
  late int t;
  setUp(() async {
    h = DriftHarness();
    repo = h.content;
    t = (await h.targets.insert(aTarget())).id;
  });
  tearDown(() => h.dispose());

  Future<int> add(String r, int slides) async => (await repo.insertIfNew(
    aContent(t, remoteId: r),
    [for (var i = 0; i < slides; i++) aMedia(slideIndex: i)],
  )).contentId;

  test('drift: other slides and other posts keep their rows', () async {
    final a = await add('a', 3);
    final b = await add('b', 2);
    final ids = (await repo.getById(a))!.media.map((m) => m.id).toList();
    await repo.deleteMediaFile(ids[1]);
    expect((await repo.getById(a))!.media.map((m) => m.id), [ids[0], ids[2]]);
    expect((await repo.getById(b))!.media, hasLength(2));
  });

  test('drift: deleting the same id twice is a no-op, not an error', () async {
    final a = await add('a', 2);
    final id = (await repo.getById(a))!.media.first.id;
    await repo.deleteMediaFile(id);
    await repo.deleteMediaFile(id);
    expect((await repo.getById(a))!.media, hasLength(1));
  });

  test('drift: the last slide removes the content from the library', () async {
    final a = await add('a', 1);
    final id = (await repo.getById(a))!.media.single.id;
    await repo.deleteMediaFile(id);
    expect(await repo.getById(a), isNull);
    final lib = await repo.watchLibrary(ContentFilter()).first;
    expect(lib, isEmpty);
  });
}
