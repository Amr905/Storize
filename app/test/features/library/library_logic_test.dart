import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/library/library_view.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

Target _target(int id, String name, {DateTime? stories, DateTime? posts}) =>
    Target(
      id: id,
      platform: PlatformId.instagram,
      remoteUserId: 'u$id',
      username: name,
      category: TargetCategory.ownClient,
      postsWatermarkAt: DateTime.utc(2026),
      addedAt: DateTime.utc(2026),
      lastStoriesCheckAt: stories,
      lastPostsCheckAt: posts,
    );

ContentWithMedia _item(
  int id,
  int targetId,
  DateTime local, {
  ContentKind kind = ContentKind.story,
  PostType? postType,
  bool viewed = false,
  MediaType media = MediaType.photo,
}) => ContentWithMedia(
  Content(
    id: id,
    targetId: targetId,
    kind: kind,
    remoteId: 'r$id',
    postType: postType,
    postedAt: local.toUtc(),
    slideCount: 1,
    detectedAt: local.toUtc(),
    viewed: viewed,
  ),
  [
    MediaFile(
      id: id,
      contentId: id,
      slideIndex: 0,
      mediaType: media,
      sourceUrl: 'https://example.invalid/$id',
    ),
  ],
);

void main() {
  final now = DateTime(2026, 11, 20, 12).toUtc();

  group('LibraryFilters', () {
    test('presets use local midnights', () {
      final today = LibraryFilters(
        date: DatePreset.today,
      ).toContentFilter(LibraryKind.stories, now);
      expect(today.from, DateTime(2026, 11, 20).toUtc());
      final d7 = LibraryFilters(
        date: DatePreset.days7,
      ).toContentFilter(LibraryKind.stories, now);
      expect(d7.from, DateTime(2026, 11, 14).toUtc());
      final d30 = LibraryFilters(
        date: DatePreset.days30,
      ).toContentFilter(LibraryKind.stories, now);
      expect(d30.from, DateTime(2026, 10, 22).toUtc());
    });

    test('a custom range includes its last day', () {
      final f = LibraryFilters(
        date: DatePreset.custom,
        customFrom: DateTime(2026, 11, 10),
        customTo: DateTime(2026, 11, 12),
      ).toContentFilter(LibraryKind.stories, now);
      expect(f.from, DateTime(2026, 11, 10).toUtc());
      expect(f.to, DateTime(2026, 11, 13).toUtc());
    });

    test('type maps to media type, kind to content kind', () {
      final f = LibraryFilters(
        type: TypeFilter.videos,
      ).toContentFilter(LibraryKind.posts, now);
      expect(f.mediaType, MediaType.video);
      expect(f.kind, ContentKind.post);
    });

    test('carousel and reel mean nothing for stories', () {
      final f = LibraryFilters(type: TypeFilter.reels);
      expect(f.effectiveType(LibraryKind.stories), TypeFilter.all);
      expect(f.effectiveType(LibraryKind.posts), TypeFilter.reels);
    });

    test('isActive ignores the kind and equality is by value', () {
      expect(LibraryFilters.none.isActive, isFalse);
      expect(LibraryFilters(targetIds: const {1}).isActive, isTrue);
      expect(
        LibraryFilters(targetIds: const {1}),
        LibraryFilters(targetIds: const {1}),
      );
      expect(
        LibraryFilters(targetIds: const {1}).hashCode,
        LibraryFilters(targetIds: const {1}).hashCode,
      );
    });
  });

  group('groupLibrary', () {
    test('groups by day, then account, in rows of three', () {
      final t1 = _target(1, 'a');
      final t2 = _target(2, 'b');
      final items = [
        _item(1, 1, DateTime(2026, 11, 20, 10)),
        _item(2, 2, DateTime(2026, 11, 20, 9)),
        _item(3, 1, DateTime(2026, 11, 20, 8)),
        _item(4, 1, DateTime(2026, 11, 20, 7)),
        _item(5, 1, DateTime(2026, 11, 20, 6), viewed: true),
        _item(6, 1, DateTime(2026, 11, 19, 23)),
      ];
      final groups = groupLibrary(items, {1: t1, 2: t2});
      expect(groups, hasLength(2));
      expect(groups[0].day, DateTime(2026, 11, 20));
      final rows = groups[0].rows;
      // a: header + (3 + 1) rows, b: header + 1 row.
      expect(rows.map((r) => r.runtimeType).toList(), [
        AccountHeaderRow,
        TilesRow,
        TilesRow,
        AccountHeaderRow,
        TilesRow,
      ]);
      final header = rows.first as AccountHeaderRow;
      expect(header.count, 4);
      expect(header.newCount, 3);
      expect((rows[1] as TilesRow).items, hasLength(3));
      expect((rows[2] as TilesRow).items, hasLength(1));
      expect(groups[1].day, DateTime(2026, 11, 19));
    });
  });

  group('buildLibraryView', () {
    final t1 = _target(1, 'a', stories: DateTime.utc(2026, 11, 20, 8));
    final t2 = _target(
      2,
      'b',
      stories: DateTime.utc(2026, 11, 20, 9),
      posts: DateTime.utc(2026, 11, 19),
    );
    final all = [
      _item(1, 1, DateTime(2026, 11, 20, 10)),
      _item(2, 2, DateTime(2026, 11, 20, 9), viewed: true),
      _item(
        3,
        1,
        DateTime(2026, 11, 20, 8),
        kind: ContentKind.post,
        postType: PostType.carousel,
      ),
      _item(
        4,
        2,
        DateTime(2026, 11, 18, 8),
        kind: ContentKind.post,
        postType: PostType.reel,
        media: MediaType.video,
      ),
    ];

    LibraryView view(LibraryKind kind, [LibraryFilters? f]) => buildLibraryView(
      all: all,
      targets: [t1, t2],
      kind: kind,
      filters: f ?? LibraryFilters.none,
      now: now,
    );

    test('counts unviewed per kind regardless of the filters', () {
      final v = view(LibraryKind.stories, LibraryFilters(targetIds: const {2}));
      expect(v.unviewedStories, 1);
      expect(v.unviewedPosts, 2);
      expect(v.itemCount, 1);
      expect(v.totalOfKind, 2);
      expect(v.filtersActive, isTrue);
    });

    test('post shape filter is applied client-side', () {
      final v = view(
        LibraryKind.posts,
        LibraryFilters(type: TypeFilter.carousels),
      );
      expect(v.itemCount, 1);
      expect(v.items.single.content.id, 3);
    });

    test('last check is the newest of the kind', () {
      expect(
        view(LibraryKind.stories).lastCheck,
        DateTime.utc(2026, 11, 20, 9),
      );
      expect(view(LibraryKind.posts).lastCheck, DateTime.utc(2026, 11, 19));
    });

    test('items iterates the groups in display order', () {
      expect(view(LibraryKind.stories).items.map((e) => e.content.id), [1, 2]);
    });
  });
}
