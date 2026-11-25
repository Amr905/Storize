import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

String _dn({
  required String username,
  required DateTime postedAt,
  required String remoteId,
  required String ext,
  int? slideIndex,
}) => '${username}_$remoteId${slideIndex == null ? '' : '_$slideIndex'}.$ext';

RemoteContent _remote(
  String id, {
  ContentKind kind = ContentKind.post,
  int slides = 1,
}) => RemoteContent(
  remoteId: id,
  kind: kind,
  postType: kind == ContentKind.post ? PostType.photo : null,
  shortcode: kind == ContentKind.post ? 'c$id' : null,
  postedAt: s.t0,
  slides: [
    for (var i = 0; i < slides; i++)
      RemoteMedia(
        index: i,
        type: MediaType.photo,
        url: 'https://cdn.example.test/$id/$i',
        width: 10,
        height: 10,
      ),
  ],
);

const _user = RemoteUser(
  remoteUserId: '42',
  username: 'zed',
  followedByViewer: true,
  blockedByViewer: false,
);

void main() {
  late FakeContentPlatform platform;
  late FakeDiagnosticLog log;

  setUp(() {
    platform = FakeContentPlatform();
    log = FakeDiagnosticLog();
  });

  group('PreviewProfile', () {
    PreviewProfile build({Future<void> Function()? onFinished}) =>
        PreviewProfile(
          platform: platform,
          log: log,
          onFinished: onFinished,
          stepTimeout: const Duration(milliseconds: 50),
        );

    test(
      'loads stories and the first page with the foreground policy',
      () async {
        var closed = 0;
        platform.resolveUserResults.add(const Ok(_user));
        platform.fetchStoriesResults.add(
          Ok({
            '42': [_remote('s1', kind: ContentKind.story)],
          }),
        );
        platform.fetchPostPageResults.add(
          Ok(PostPage(items: [_remote('p1'), _remote('p2')], nextCursor: 'x')),
        );
        final r = await build(onFinished: () async => closed++).run('zed');
        final p = (r as Ok<ProfilePreview>).value;
        expect(p.stories.map((c) => c.remoteId), ['s1']);
        expect(p.posts.map((c) => c.remoteId), ['p1', 'p2']);
        expect(p.storiesFailure, isNull);
        expect(p.postsFailure, isNull);
        expect(closed, 1, reason: 'the in-page session is closed once');
        expect(
          platform.callsTo('fetchStories').single.args.last,
          isA<ExtractionPolicy>(),
        );
        final page = platform.callsTo('fetchPostPage').single.args;
        expect(page[1], isNull);
        expect(page[2], ExtractionPolicy.directThenPage);
        expect(log.entries.map((e) => e.message), [
          'start',
          'resolve ok',
          'stories n=1',
          'posts n=2',
        ]);
      },
    );

    test('a stories failure does not hide the posts', () async {
      platform.resolveUserResults.add(const Ok(_user));
      platform.fetchStoriesResults.add(const Err(RateLimited(null)));
      platform.fetchPostPageResults.add(Ok(PostPage(items: [_remote('p1')])));
      final p = ((await build().run('zed')) as Ok<ProfilePreview>).value;
      expect(p.storiesFailure, isA<RateLimited>());
      expect(p.stories, isEmpty);
      expect(p.posts, hasLength(1));
      expect(
        log.entries.map((e) => e.message),
        contains('stories failure=RateLimited'),
      );
    });

    test('a posts failure does not hide the stories', () async {
      platform.resolveUserResults.add(const Ok(_user));
      platform.fetchStoriesResults.add(
        Ok({
          '42': [_remote('s1', kind: ContentKind.story)],
        }),
      );
      platform.fetchPostPageResults.add(const Err(SchemaChanged('x')));
      final p = ((await build().run('zed')) as Ok<ProfilePreview>).value;
      expect(p.postsFailure, isA<SchemaChanged>());
      expect(p.stories, hasLength(1));
    });

    test('a resolve failure ends the run, still closes the session', () async {
      var closed = 0;
      platform.resolveUserResults.add(const Err(TargetNotFound()));
      final r = await build(onFinished: () async => closed++).run('zed');
      expect(r.failureOrNull, isA<TargetNotFound>());
      expect(platform.callsTo('fetchStories'), isEmpty);
      expect(closed, 1);
      expect(log.entries.last.message, 'resolve failure=TargetNotFound');
    });

    test('a hanging call becomes a network failure', () async {
      platform.resolveUserResults.add(const Ok(_user));
      platform.fetchStoriesResults.add(const Ok({}));
      platform.fetchPostPageResults.add(Ok(PostPage(items: const [])));
      final hang = _Hang(FakeContentPlatform());
      final p = ((await PreviewProfile(
        platform: hang,
        stepTimeout: const Duration(milliseconds: 20),
      ).run('zed')) as Ok<ProfilePreview>).value;
      expect(p.storiesFailure, isA<NetworkFailure>());
    });

    test('logs hold no username, id or url', () async {
      platform.resolveUserResults.add(const Ok(_user));
      platform.fetchStoriesResults.add(
        Ok({
          '42': [_remote('s1', kind: ContentKind.story)],
        }),
      );
      platform.fetchPostPageResults.add(Ok(PostPage(items: [_remote('p1')])));
      await build().run('zed');
      for (final e in log.entries) {
        expect(e.tag, 'preview');
        expect(e.message, isNot(contains('zed')));
        expect(e.message, isNot(contains('42')));
        expect(e.message, isNot(contains('http')));
      }
    });
  });

  group('SavePreviewItems', () {
    late FakeClock clock;
    late FakeTargetRepo targets;
    late FakeContentRepo content;
    late FakeMediaCache cache;
    late FakeGalleryStore gallery;
    late SavePreviewItems save;

    setUp(() {
      clock = FakeClock(s.t0);
      targets = FakeTargetRepo();
      content = FakeContentRepo(targets: targets);
      cache = FakeMediaCache();
      gallery = FakeGalleryStore(cache: cache);
      final downloads = DownloadPending(
        content: content,
        targets: targets,
        activity: FakeActivityRepo(clock),
        platform: platform,
        cache: cache,
        gallery: gallery,
        storage: FakeStorageInfo(),
        clock: clock,
        leases: FakeGovernorLeaseRepo(clock),
        displayName: _dn,
        relativeDir: (u) => 'Pictures/Storize/$u',
      );
      save = SavePreviewItems(
        targets: targets,
        content: content,
        downloads: downloads,
        platform: platform,
        clock: clock,
        log: log,
      );
    });

    void media(int n) {
      for (var i = 0; i < n; i++) {
        platform.queueMedia(List<int>.filled(8, 7));
      }
    }

    test('an untracked account gets a preview-only target', () async {
      media(1);
      final r = await save(user: _user, items: [_remote('p1')]);
      final t = (await targets.getById(r.target.id))!;
      expect(t.username, 'zed');
      expect(t.status, TargetStatus.paused);
      expect(SavePreviewItems.isPreviewOnly(t), isTrue);
      expect(
        await targets.listActive(CheckScope.stories),
        isEmpty,
        reason: 'no check visits it',
      );
      expect(await targets.listActive(CheckScope.posts), isEmpty);
    });

    test('saves into the gallery and reports saved', () async {
      media(2);
      final r = await save(
        user: _user,
        items: [
          _remote('p1'),
          _remote('s1', kind: ContentKind.story),
        ],
      );
      expect(r.saved, 2);
      expect(r.failed, 0);
      expect(gallery.files, hasLength(2));
      expect(
        gallery.files.every((f) => f.relativePath == 'Pictures/Storize/zed'),
        isTrue,
      );
      expect(log.entries.last.message, 'save n=2 saved=2 failed=0');
    });

    test('a second save is already saved and downloads nothing', () async {
      media(1);
      await save(user: _user, items: [_remote('p1')]);
      final r = await save(user: _user, items: [_remote('p1')]);
      expect(r.items.single.status, PreviewSaveStatus.alreadySaved);
      expect(gallery.files, hasLength(1));
      expect(await content.listByTarget(r.target.id), hasLength(1));
      expect(await targets.watchAll().first, hasLength(1));
    });

    test('duplicates in one call are one item', () async {
      media(1);
      final r = await save(user: _user, items: [_remote('p1'), _remote('p1')]);
      expect(r.items, hasLength(1));
      expect(gallery.files, hasLength(1));
    });

    test('a tracked target is reused and keeps its flags', () async {
      final t = await targets.insert(
        s.target().copyWith(remoteUserId: '42', username: 'zed'),
      );
      media(1);
      final r = await save(user: _user, items: [_remote('p1')], targetId: t.id);
      expect(r.target.id, t.id);
      expect(r.target.status, TargetStatus.active);
      expect(await targets.watchAll().first, hasLength(1));
    });

    test('only the chosen items download, other pending rows wait', () async {
      final other = await targets.insert(s.target());
      final stray = await content.insertIfNew(
        s.content(targetId: other.id, remoteId: 'old'),
        [s.media()],
      );
      media(1);
      await save(user: _user, items: [_remote('p1')]);
      final left = (await content.getById(stray.contentId))!;
      expect(left.media.single.status, MediaFileStatus.pending);
    });

    test('a failed download is reported with a reason', () async {
      platform.queueMediaError(StateError('boom'));
      final r = await save(user: _user, items: [_remote('p1')]);
      expect(r.items.single.status, PreviewSaveStatus.failed);
      expect(r.items.single.reason, isNotNull);
      expect(r.failed, 1);
      expect(log.entries.last.message, 'save n=1 saved=0 failed=1');
    });

    test('an item without media fails as no_media', () async {
      final r = await save(user: _user, items: [_remote('p1', slides: 0)]);
      expect(r.items.single.reason, 'no_media');
    });

    test('activatePreviewTarget starts normal tracking', () async {
      media(1);
      final r = await save(user: _user, items: [_remote('p1')]);
      final t = await save.activatePreviewTarget(r.target.id);
      expect(t.status, TargetStatus.active);
      expect(t.statusReason, isNull);
      expect(await targets.listActive(CheckScope.posts), hasLength(1));
    });
  });
}

/// A platform whose story fetch never answers; the rest is scripted.
final class _Hang implements ContentPlatform {
  _Hang(this._inner) {
    _inner.resolveUserResults.add(const Ok(_user));
    _inner.fetchPostPageResults.add(Ok(PostPage(items: const [])));
  }

  final FakeContentPlatform _inner;

  @override
  PlatformId get id => _inner.id;

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds, {
    required ExtractionPolicy policy,
  }) => Completer<Result<Map<String, List<RemoteContent>>>>().future;

  @override
  Future<Result<RemoteUser>> resolveUser(String username) =>
      _inner.resolveUser(username);

  @override
  Future<Result<PostPage>> fetchPostPage(
    String userId, {
    required ExtractionPolicy policy,
    String? cursor,
  }) => _inner.fetchPostPage(userId, policy: policy, cursor: cursor);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
