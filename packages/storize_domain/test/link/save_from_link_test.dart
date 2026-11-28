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

RemoteContent _remote(String id, {ContentKind kind = ContentKind.post}) =>
    RemoteContent(
      remoteId: id,
      kind: kind,
      postType: kind == ContentKind.post ? PostType.photo : null,
      shortcode: kind == ContentKind.post ? 'c$id' : null,
      postedAt: s.t0,
      extras: kind == ContentKind.highlight
          ? {HighlightExtras.title: 'Trip', HighlightExtras.id: 'h1'}
          : const {},
      slides: [
        RemoteMedia(
          index: 0,
          type: MediaType.photo,
          url: 'https://cdn.example.test/$id/0',
          width: 10,
          height: 10,
        ),
      ],
    );

RemoteUser _user({bool isPrivate = false, bool followed = true}) => RemoteUser(
  remoteUserId: '42',
  username: 'zed',
  isPrivate: isPrivate,
  followedByViewer: followed,
  blockedByViewer: false,
);

void main() {
  late FakeContentPlatform platform;
  late FakeDiagnosticLog log;
  late FakeTargetRepo targets;
  late FakeContentRepo content;
  late FakeGalleryStore gallery;
  late SaveFromLink uc;
  late SavePreviewItems savePreview;
  var finished = 0;

  setUp(() {
    finished = 0;
    platform = FakeContentPlatform();
    log = FakeDiagnosticLog();
    final clock = FakeClock(s.t0);
    targets = FakeTargetRepo();
    content = FakeContentRepo(targets: targets);
    final cache = FakeMediaCache();
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
    savePreview = SavePreviewItems(
      targets: targets,
      content: content,
      downloads: downloads,
      platform: platform,
      clock: clock,
      log: log,
    );
    uc = SaveFromLink(
      platform: platform,
      source: platform,
      targets: targets,
      content: content,
      save: savePreview,
      log: log,
      onFinished: () async => finished++,
      stepTimeout: const Duration(milliseconds: 50),
    );
  });

  void media(int n) {
    for (var i = 0; i < n; i++) {
      platform.queueMedia(List<int>.filled(8, 7));
    }
  }

  const storyLink = 'https://www.instagram.com/stories/zed/3001/?igsh=ZZFAKE';

  group('story', () {
    test(
      'finds the item by pk, saves it, creates a preview-only target',
      () async {
        platform.resolveUserResults.add(Ok(_user()));
        platform.fetchStoriesResults.add(
          Ok({
            '42': [
              _remote('3000', kind: ContentKind.story),
              _remote('3001', kind: ContentKind.story),
            ],
          }),
        );
        media(1);
        final found = await uc.lookupText(storyLink) as LinkFound;
        expect(found.preview.focus?.remoteId, '3001');
        expect(found.preview.items, hasLength(1));
        expect(found.preview.focusSaved, isFalse);
        expect(finished, 1, reason: 'the in-page session is closed');
        expect(
          platform.callsTo('fetchStories').single.args.last,
          ExtractionPolicy.directThenPage,
        );

        final r = (await uc.save(found.preview))!;
        expect(r.saved, 1);
        expect(gallery.files, hasLength(1));
        expect(gallery.files.single.relativePath, 'Pictures/Storize/zed');
        final t = (await targets.getById(r.target.id))!;
        expect(SavePreviewItems.isPreviewOnly(t), isTrue);
      },
    );

    test('an expired story is "gone"', () async {
      platform.resolveUserResults.add(Ok(_user()));
      platform.fetchStoriesResults.add(
        Ok({
          '42': [_remote('3000', kind: ContentKind.story)],
        }),
      );
      expect(await uc.lookupText(storyLink), isA<LinkGone>());
      platform.resolveUserResults.add(Ok(_user()));
      platform.fetchStoriesResults.add(const Ok({}));
      final r = await uc.lookupText(storyLink) as LinkGone;
      expect(r.kind, LinkKind.story);
    });

    test('an unknown user is gone; a private account is not visible', () async {
      platform.resolveUserResults.addFailure(const TargetNotFound());
      expect(await uc.lookupText(storyLink), isA<LinkGone>());
      platform.resolveUserResults.add(
        Ok(_user(isPrivate: true, followed: false)),
      );
      final r = await uc.lookupText(storyLink) as LinkFailed;
      expect(r.failure, isA<TargetNotVisible>());
      expect(
        platform.callsTo('fetchStories'),
        isEmpty,
        reason: 'nothing is asked for a private account',
      );
    });
  });

  group('post and reel', () {
    test('a post by shortcode is saved', () async {
      platform.fetchPostByShortcodeResults.add(
        Ok(LinkedItems(user: _user(), items: [_remote('p1')])),
      );
      media(1);
      final found = await uc.lookupText(
        'https://www.instagram.com/p/ZZFAKE_c1/',
      ) as LinkFound;
      expect(platform.callsTo('fetchPostByShortcode').single.args, [
        'ZZFAKE_c1',
        ExtractionPolicy.directThenPage,
      ]);
      expect(found.preview.focus?.remoteId, 'p1');
      final r = (await uc.save(found.preview))!;
      expect(r.saved, 1);
    });

    test('a reel link uses the same query', () async {
      platform.fetchPostByShortcodeResults.add(
        Ok(LinkedItems(user: _user(), items: [_remote('p1')])),
      );
      final found = await uc.lookupText(
        'https://www.instagram.com/reel/ZZFAKE_c1/',
      ) as LinkFound;
      expect(found.preview.link.kind, LinkKind.reel);
    });

    test('removed is gone; private is not visible', () async {
      platform.fetchPostByShortcodeResults.addFailure(const TargetNotFound());
      expect(
        await uc.lookupText('https://www.instagram.com/p/ZZFAKE_c1/'),
        isA<LinkGone>(),
      );
      platform.fetchPostByShortcodeResults.addFailure(const TargetNotVisible());
      final r = await uc.lookupText(
        'https://www.instagram.com/p/ZZFAKE_c1/',
      ) as LinkFailed;
      expect(r.failure, isA<TargetNotVisible>());
    });
  });

  group('highlight', () {
    LinkedItems hl() => LinkedItems(
      user: _user(),
      items: [
        _remote('3001', kind: ContentKind.highlight),
        _remote('3002', kind: ContentKind.highlight),
        _remote('3003', kind: ContentKind.highlight),
      ],
    );

    test('story_media_id picks one item', () async {
      platform.fetchHighlightWithOwnerResults.add(Ok(hl()));
      media(1);
      final found = await uc.lookupText(
        'https://www.instagram.com/stories/highlights/1700001/'
        '?story_media_id=3002_42',
      ) as LinkFound;
      expect(found.preview.focus?.remoteId, '3002');
      expect(found.preview.items, hasLength(3));
      expect(found.preview.title, 'Trip');
      final r = (await uc.save(found.preview))!;
      expect(r.items, hasLength(1));
      expect(r.saved, 1);
    });

    test('without a media id every item can be saved ("Save all N")', () async {
      platform.fetchHighlightWithOwnerResults.add(Ok(hl()));
      media(3);
      final found = await uc.lookupText(
        'https://www.instagram.com/stories/highlights/1700001/',
      ) as LinkFound;
      expect(found.preview.focus, isNull);
      expect(found.preview.unsavedCount, 3);
      final r = (await uc.save(found.preview, all: true))!;
      expect(r.saved, 3);
    });

    test('an empty or removed highlight is gone', () async {
      platform.fetchHighlightWithOwnerResults.add(
        Ok(LinkedItems(user: _user(), items: const [])),
      );
      expect(
        await uc.lookupText(
          'https://www.instagram.com/stories/highlights/1700001/',
        ),
        isA<LinkGone>(),
      );
    });
  });

  group('duplicates', () {
    test('a saved item shows as saved and nothing downloads again', () async {
      platform.fetchPostByShortcodeResults
        ..add(Ok(LinkedItems(user: _user(), items: [_remote('p1')])))
        ..add(Ok(LinkedItems(user: _user(), items: [_remote('p1')])));
      media(1);
      const link = 'https://www.instagram.com/p/ZZFAKE_c1/';
      final first = await uc.lookupText(link) as LinkFound;
      final saved = (await uc.save(first.preview))!;
      expect(saved.saved, 1);

      final again = await uc.lookupText(link) as LinkFound;
      expect(again.preview.focusSaved, isTrue);
      expect(again.preview.savedContentIds['p1'], isNotNull);
      expect(await uc.save(again.preview), isNull);
      expect(gallery.files, hasLength(1));
    });
  });

  group('errors and logs', () {
    test('rate limited, session invalid and network are passed on', () async {
      for (final f in <Failure>[
        const RateLimited(null),
        const SessionInvalid(SessionReason.loginRequired),
        const NetworkFailure(),
      ]) {
        platform.fetchPostByShortcodeResults.addFailure(f);
        final r = await uc.lookupText(
          'https://www.instagram.com/p/ZZFAKE_c1/',
        ) as LinkFailed;
        expect(r.failure, f);
      }
    });

    test('a hanging platform is a network failure', () async {
      final hang = SaveFromLink(
        platform: _Hang(),
        source: platform,
        targets: targets,
        content: content,
        save: savePreview,
        stepTimeout: const Duration(milliseconds: 20),
      );
      final r = await hang.lookupText(storyLink) as LinkFailed;
      expect(r.failure, isA<NetworkFailure>());
    });

    test('a throwing source is caught as a failure', () async {
      final throwing = SaveFromLink(
        platform: platform,
        source: _Throw(),
        targets: targets,
        content: content,
        save: savePreview,
        onFinished: () async => finished++,
      );
      final r = await throwing.lookupText(
        'https://www.instagram.com/p/ZZFAKE_c1/',
      ) as LinkFailed;
      expect(r.failure, isA<UnknownFailure>());
      expect(finished, 1);
    });

    test('an unsupported text is reported and nothing is asked', () async {
      expect(await uc.lookupText('hello'), isA<LinkUnsupported>());
      expect(platform.calls, isEmpty);
    });

    test('logs hold the kind and outcome only, never the link', () async {
      platform.fetchPostByShortcodeResults.add(
        Ok(LinkedItems(user: _user(), items: [_remote('p1')])),
      );
      media(1);
      final found = await uc.lookupText(
        'https://www.instagram.com/p/ZZFAKE_c1/?igsh=ZZFAKE_tok',
      ) as LinkFound;
      await uc.save(found.preview);
      final text = log.entries.map((e) => '${e.tag} ${e.message}').join('\n');
      expect(text, contains('link lookup kind=post outcome=found'));
      expect(text, contains('link save kind=post'));
      for (final secret in ['ZZFAKE', 'zed', '42', 'instagram.com', 'p1']) {
        expect(
          log.entries.where(
            (e) => e.tag == 'link' && e.message.contains(secret),
          ),
          isEmpty,
          reason: secret,
        );
      }
      expect(log.entries.every((e) => e.level == LogLevel.info), isTrue);
    });
  });
}

final class _Hang implements ContentPlatform {
  @override
  PlatformId get id => PlatformId.instagram;

  @override
  Future<Result<RemoteUser>> resolveUser(String username) =>
      Completer<Result<RemoteUser>>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _Throw implements LinkedContentSource {
  @override
  Future<Result<LinkedItems>> fetchPostByShortcode(
    String shortcode, {
    required ExtractionPolicy policy,
  }) async => throw StateError('boom');

  @override
  Future<Result<LinkedItems>> fetchHighlightWithOwner(
    String highlightId, {
    required ExtractionPolicy policy,
  }) async => throw StateError('boom');
}
