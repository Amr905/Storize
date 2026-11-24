// T-041 page mode: scrolling post pages, the tray, and highlight pages with
// the seen mutation kept blocked.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

const _userId = 'ZZFAKE_user_a';
const Map<String, String> _names = {_userId: fakeUser};

HookEvent _posts(String file) =>
    hookResponse(loadSynthetic(file), name: postsName);

/// Page 1 on load, page 2 and 3 on the first two scrolls.
Rig _scrollRig({int pageSize = 3, int maxSteps = 30, bool more = true}) {
  late Rig rig;
  rig = Rig(
    usernames: _names,
    postPageSize: pageSize,
    maxScrollSteps: maxSteps,
    onLoad: (s, url) {
      s
        ..emit(_posts('timeline_page1.json'))
        ..emit(const LoadStopEvent());
    },
  );
  rig.driver.onScroll = (s, step) {
    if (!more) return;
    if (step == 1) s.emit(_posts('timeline_page2.json'));
    if (step == 2) s.emit(_posts('timeline_page3.json'));
  };
  return rig;
}

void main() {
  group('fetchPostPage (scroll)', () {
    test('pages by cursor; the last page has no cursor', () async {
      final rig = _scrollRig();
      final p1 = (await rig.run(rig.extractor.fetchPostPage(_userId)))
          .valueOrNull!;
      expect(p1.items.map((c) => c.remoteId), [
        'ZZFAKE_p_1001',
        'ZZFAKE_p_1002',
        'ZZFAKE_p_1003',
      ]);
      final c1 = PostCursor.parse(p1.nextCursor!)!;
      expect(c1.igCursor, isEmpty);
      expect(c1.takenAt.millisecondsSinceEpoch, 1800000700 * 1000);

      final p2 = (await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: p1.nextCursor),
      )).valueOrNull!;
      expect(p2.items.map((c) => c.remoteId), [
        'ZZFAKE_p_1004',
        'ZZFAKE_p_1005',
        'ZZFAKE_p_1006',
      ]);
      final p3 = (await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: p2.nextCursor),
      )).valueOrNull!;
      expect(p3.items.map((c) => c.remoteId), [
        'ZZFAKE_p_1007',
        'ZZFAKE_p_pinned_old',
      ]);
      expect(p3.nextCursor, isNull);
      // One governed page load per call, scrolls inside it.
      expect(rig.driver.sessions, hasLength(3));
    });

    test('scrolling is bounded and a stall is SchemaChanged', () async {
      final rig = _scrollRig(maxSteps: 2, more: false);
      final cursor = PostCursor(
        takenAt: DateTime.utc(1990),
        igCursor: '',
      ).encode();
      final r = await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: cursor),
      );
      expect(r.failureOrNull, isA<SchemaChanged>());
      expect(rig.driver.sessions.single.scrolls, 2);
      expect(rig.driver.sessions.single.disposed, isTrue);
      expect(await rig.governor.remainingTokens(1), 3, reason: 'one pageLoad');
    });

    test('an unknown username loads nothing', () async {
      final rig = Rig(usernames: const {}, onLoad: (_, _) {});
      final r = await rig.run(rig.extractor.fetchPostPage(_userId));
      expect(r.failureOrNull, isA<UnknownFailure>());
      expect(rig.driver.sessions, isEmpty);
    });
  });

  group('highlights (page)', () {
    test('the tray comes from the profile page', () async {
      final rig = Rig(
        usernames: _names,
        onLoad: (s, url) => s.emit(
          hookResponse(
            loadSynthetic('highlights_tray.json'),
            name: GraphqlQuery.highlights.friendlyName,
          ),
        ),
      );
      final tray = (await rig.run(rig.extractor.fetchHighlights(_userId)))
          .valueOrNull!;
      expect(tray.map((h) => h.id), ['ZZFAKE_hl_1', 'ZZFAKE_hl_2']);
      expect(rig.driver.sessions.single.loads.single.path, '/$fakeUser/');
      expect(rig.discovery.toString(), contains('docIds: 1'));
    });

    test('items from /stories/highlights/<id>/; the seen mutation is '
        'blocked and counted', () async {
      final rig = Rig(
        usernames: _names,
        onLoad: (s, url) {
          s
            ..emit(hookBlocked(seenName))
            ..emit(
              hookResponse(
                loadSynthetic('highlight_reel.json'),
                name: storiesName,
              ),
            );
        },
      );
      final out = (await rig.run(
        rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1'], orderStart: 4),
      )).valueOrNull!;
      expect(
        rig.driver.sessions.single.loads.single.path,
        '/stories/highlights/ZZFAKE_hl_1/',
      );
      final items = out['ZZFAKE_hl_1']!;
      expect(items, hasLength(2));
      expect(items.first.kind, ContentKind.highlight);
      expect(items.first.extras[HighlightExtras.order], 4);
      expect(rig.extractor.blockedRequestCount, 1);
      expect(rig.extractor.seenLeakCount, 0);
    });

    test(
      'a seen reply on a highlight page is a leak: the guard trips',
      () async {
        final guard = SeenGuard();
        final rig = Rig(
          usernames: _names,
          seenGuard: guard,
          onLoad: (s, url) => s.emit(
            hookResponse({
              'data': {'xdt_mark_story_reel_seen': <String, Object?>{}},
            }, name: seenName),
          ),
        );
        final r = await rig.run(
          rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1']),
        );
        expect(r.failureOrNull, isA<UnknownFailure>());
        expect(guard.tripped, isTrue);
        // Tripped: the next highlight page is refused before any load.
        final again = await rig.run(
          rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1']),
        );
        expect(again.failureOrNull, isA<UnknownFailure>());
        expect(rig.driver.sessions, hasLength(1));
      },
    );

    test(
      'a path-like id is refused; no ids, titles or URLs are logged',
      () async {
        final rig = Rig(
          usernames: _names,
          onLoad: (s, url) => s.emit(
            hookResponse(
              loadSynthetic('highlight_reel.json'),
              name: storiesName,
            ),
          ),
        );
        final bad = await rig.run(
          rig.extractor.fetchHighlightItems(['../x']),
        );
        expect(bad.failureOrNull, isA<UnknownFailure>());
        expect(rig.driver.sessions, isEmpty);
        await rig.run(rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1']));
        for (final w in ['ZZFAKE_hl', 'Title One', 'cdn.example']) {
          expect(rig.allLogs, isNot(contains(w)), reason: w);
        }
      },
    );
  });
}
