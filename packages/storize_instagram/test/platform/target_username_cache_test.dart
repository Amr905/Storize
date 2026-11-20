// T-014 QA-F12 / T-013: the persistent UsernameCache over TargetRepo.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_model/storize_model.dart';

Target _target(String id, String name) => Target(
  id: 0,
  platform: PlatformId.instagram,
  remoteUserId: id,
  username: name,
  category: TargetCategory.public,
  postsWatermarkAt: DateTime.utc(2026),
  addedAt: DateTime.utc(2026),
);

void main() {
  late FakeTargetRepo repo;
  late TargetRepoUsernameCache cache;

  setUp(() async {
    repo = FakeTargetRepo();
    await repo.insert(_target('u1', 'stored_name'));
    cache = TargetRepoUsernameCache(repo);
  });

  test('reads the stored username of a target (survives a restart)', () async {
    expect(await cache.usernameOf('u1'), 'stored_name');
    // A new cache object = a restart: the repo is the memory.
    expect(await TargetRepoUsernameCache(repo).usernameOf('u1'), 'stored_name');
  });

  test('an unknown id is null', () async {
    expect(await cache.usernameOf('nope'), isNull);
  });

  test('remember keeps a name for a user who is not a target yet', () async {
    await cache.remember('u2', 'new_user');
    expect(await cache.usernameOf('u2'), 'new_user');
    expect(await repo.getByRemoteUserId(PlatformId.instagram, 'u2'), isNull);
  });

  test('a remembered newer name wins over the stored one, but the repo is '
      'NOT written (RunCheck owns the rename, EC-5)', () async {
    await cache.remember('u1', 'renamed');
    expect(await cache.usernameOf('u1'), 'renamed');
    final row = (await repo.getByRemoteUserId(PlatformId.instagram, 'u1'))!;
    expect(row.username, 'stored_name');
  });

  test('only Instagram targets of that platform id are read', () async {
    await repo.insert(_target('u3', 'other'));
    expect(await cache.usernameOf('u3'), 'other');
  });

  test('a repo that throws surfaces the error (the extractors treat it as a '
      'miss)', () async {
    final broken = TargetRepoUsernameCache(_BrokenRepo());
    await expectLater(broken.usernameOf('u1'), throwsA(isA<StateError>()));
    // remember never touches the repo, so it cannot fail.
    await broken.remember('u1', 'x');
    expect(await broken.usernameOf('u1'), 'x');
  });
}

/// A repo whose lookup fails; everything else is unused by the cache.
final class _BrokenRepo implements TargetRepo {
  @override
  Future<Target?> getByRemoteUserId(PlatformId p, String id) =>
      throw StateError('db down');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
