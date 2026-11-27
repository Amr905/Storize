// T-055: the drift search query behind the S-04 search field (FR-76).
// Covers each searched field, case-insensitivity, LIKE escaping, the filter
// combinations and that an empty query equals the plain library.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/daos/content_dao.dart' show escapeLikePattern;
import 'package:storize_data/db/db.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'support/builders.dart';
import 'support/harness.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftHarness h;
  late Target alpha;
  late Target beta;
  late Target under;
  late Target plain;

  setUp(() async {
    h = DriftHarness();
    alpha = await h.targets.insert(
      aTarget(),
    );
    beta = await h.targets.insert(
      aTarget(remoteUserId: 'b', username: 'Beta_User'),
    );
    under = await h.targets.insert(
      aTarget(remoteUserId: 'c', username: 'under_score'),
    );
    plain = await h.targets.insert(
      aTarget(remoteUserId: 'd', username: 'underxscore'),
    );
  });
  tearDown(() => h.dispose());

  Future<int> add(
    Target t, {
    String remoteId = 'r',
    ContentKind kind = ContentKind.post,
    DateTime? postedAt,
    String? caption,
    String? location,
    Map<String, Object?> extras = const {},
    List<MediaType> media = const [MediaType.photo],
  }) async {
    final c = aContent(
      t.id,
      remoteId: remoteId,
      kind: kind,
      postedAt: postedAt,
      extras: extras,
    ).copyWith(caption: caption, locationName: location);
    final r = await h.content.insertIfNew(c, [
      for (var i = 0; i < media.length; i++)
        aMedia(slideIndex: i, type: media[i]),
    ]);
    return r.contentId;
  }

  Future<Set<int>> search(String q, [ContentFilter? filter]) async {
    final rows = await h.content
        .watchLibrarySearch(filter ?? ContentFilter(), q)
        .first;
    return {for (final r in rows) r.content.id};
  }

  group('fields searched', () {
    test('username, matched case-insensitively', () async {
      final id = await add(beta, caption: 'nothing here');
      await add(alpha, remoteId: 'x', caption: 'nothing here');
      expect(await search('beta_user'), {id});
      expect(await search('BETA'), {id});
    });

    test('caption, matched case-insensitively', () async {
      final id = await add(alpha, caption: 'Sunset at the BEACH');
      await add(alpha, remoteId: 'x', caption: 'mountains');
      expect(await search('beach'), {id});
    });

    test('location name', () async {
      final id = await add(alpha, location: 'Cairo Tower');
      await add(alpha, remoteId: 'x', location: 'Alexandria');
      expect(await search('cairo'), {id});
    });

    test('highlight title (stored in the extras JSON)', () async {
      final id = await add(
        alpha,
        kind: ContentKind.highlight,
        extras: {'highlightTitle': 'Summer trip'},
      );
      await add(alpha, remoteId: 'x', kind: ContentKind.highlight);
      expect(await search('summer'), {id});
    });

    test('a missing caption or location never matches', () async {
      await add(alpha);
      expect(await search('zq'), isEmpty);
    });

    test('a query that matches nothing returns nothing', () async {
      await add(alpha, caption: 'hello');
      expect(await search('zzz-no-such-text'), isEmpty);
    });

    test('an empty query returns the whole library', () async {
      final a = await add(alpha, caption: 'x');
      final b = await add(beta, remoteId: 'y');
      expect(await search(''), {a, b});
    });
  });

  group('LIKE escaping', () {
    test('% matches only a literal percent sign', () async {
      final yes = await add(alpha, caption: '100% sure');
      await add(alpha, remoteId: 'x', caption: '100 sure');
      expect(await search('100%'), {yes});
    });

    test('_ matches only a literal underscore', () async {
      final yes = await add(under, caption: 'x');
      await add(plain, remoteId: 'y', caption: 'x');
      // "under_" as a wildcard would also match "underxscore".
      expect(await search('under_'), {yes});
    });

    test('a backslash matches itself', () async {
      final yes = await add(alpha, caption: r'a\b');
      await add(alpha, remoteId: 'x', caption: 'ab');
      expect(await search(r'a\'), {yes});
    });

    test('SQL text is data, not SQL', () async {
      await add(alpha, caption: 'plain');
      expect(await search("' OR 1=1 --"), isEmpty);
      expect(await search('%'), isEmpty);
    });

    test('escapeLikePattern escapes %, _ and the escape character', () {
      expect(escapeLikePattern(r'50%_\x'), r'50\%\_\\x');
      expect(escapeLikePattern('plain'), 'plain');
    });
  });

  group('combined with the filters', () {
    test('kind narrows the search', () async {
      final post = await add(alpha, caption: 'sea');
      await add(alpha, remoteId: 'x', kind: ContentKind.story, caption: 'sea');
      expect(
        await search('sea', ContentFilter(kind: ContentKind.post)),
        {post},
      );
    });

    test('accounts narrow the search', () async {
      final a = await add(alpha, caption: 'sea');
      await add(beta, remoteId: 'x', caption: 'sea');
      expect(await search('sea', ContentFilter(targetIds: {alpha.id})), {a});
    });

    test(
      'date range narrows the search (from inclusive, to exclusive)',
      () async {
        final early = await add(
          alpha,
          caption: 'sea',
          postedAt: DateTime.utc(2026, 11, 1, 9),
        );
        final late = await add(
          alpha,
          remoteId: 'x',
          caption: 'sea',
          postedAt: DateTime.utc(2026, 11, 20, 9),
        );
        expect(
          await search(
            'sea',
            ContentFilter(from: DateTime.utc(2026, 11, 10)),
          ),
          {late},
        );
        expect(
          await search('sea', ContentFilter(to: DateTime.utc(2026, 11, 10))),
          {early},
        );
      },
    );

    test('media type narrows the search', () async {
      final video = await add(alpha, caption: 'sea', media: [MediaType.video]);
      await add(alpha, remoteId: 'x', caption: 'sea');
      expect(
        await search('sea', ContentFilter(mediaType: MediaType.video)),
        {video},
      );
    });

    test('all filters combine with the text', () async {
      final hit = await add(
        alpha,
        caption: 'sea',
        postedAt: DateTime.utc(2026, 11, 20),
        media: [MediaType.video],
      );
      await add(
        beta,
        remoteId: 'b',
        caption: 'sea',
        postedAt: DateTime.utc(2026, 11, 20),
        media: [MediaType.video],
      );
      await add(
        alpha,
        remoteId: 'c',
        caption: 'hill',
        postedAt: DateTime.utc(2026, 11, 20),
        media: [MediaType.video],
      );
      await add(
        alpha,
        remoteId: 'd',
        caption: 'sea',
        postedAt: DateTime.utc(2026, 10),
        media: [MediaType.video],
      );
      await add(
        alpha,
        remoteId: 'e',
        caption: 'sea',
        postedAt: DateTime.utc(2026, 11, 20),
      );
      expect(
        await search(
          'SEA',
          ContentFilter(
            kind: ContentKind.post,
            targetIds: {alpha.id},
            from: DateTime.utc(2026, 11),
            mediaType: MediaType.video,
          ),
        ),
        {hit},
      );
    });
  });

  test('the result updates when a matching row is added', () async {
    final w = Watch(h.content.watchLibrarySearch(ContentFilter(), 'sea'));
    addTearDown(w.cancel);
    await w.until((l) => l.isEmpty);
    await add(alpha, caption: 'sea');
    await w.until((l) => l.length == 1);
  });
}
