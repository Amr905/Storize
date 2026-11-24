import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 11, 24);

  test('HistoryProgress copyWith keeps and clears nullable fields', () {
    final p = HistoryProgress(
      state: HistoryState.running,
      cursor: 'secret-cursor',
      fetched: 3,
      oldestSeenAt: at,
      updatedAt: at,
    );
    expect(p.copyWith(fetched: 4).cursor, 'secret-cursor');
    expect(p.copyWith(cursor: null).cursor, isNull);
    expect(p.copyWith(oldestSeenAt: null).oldestSeenAt, isNull);
    expect(p.copyWith(), p);
    expect(p.copyWith(state: HistoryState.done), isNot(p));
    expect(p.toString(), isNot(contains('secret-cursor')));
  });

  test('PostPage copies its items and compares by value', () {
    final items = <RemoteContent>[];
    final page = PostPage(items: items, nextCursor: 'n');
    items.add(
      RemoteContent(
        remoteId: '1',
        kind: ContentKind.post,
        postedAt: at,
        slides: const [],
      ),
    );
    expect(page.items, isEmpty);
    expect(() => page.items.add(items.first), throwsUnsupportedError);
    expect(PostPage(items: const [], nextCursor: 'n'), page);
    expect(PostPage(items: const []), isNot(page));
  });

  test('RemoteHighlight redacts the cover URL', () {
    const h = RemoteHighlight(
      id: 'h1',
      title: 'Trip',
      coverUrl: 'https://example.invalid/sig=abc',
      itemCount: 2,
    );
    expect(h.toString(), isNot(contains('sig=abc')));
    expect(
      h,
      const RemoteHighlight(
        id: 'h1',
        title: 'Trip',
        coverUrl: 'https://example.invalid/sig=abc',
        itemCount: 2,
      ),
    );
  });

  test('a highlight item carries its extras keys', () {
    final c = RemoteContent(
      remoteId: '1',
      kind: ContentKind.highlight,
      postedAt: at,
      slides: const [],
      extras: {
        HighlightExtras.id: 'h1',
        HighlightExtras.title: 'Trip',
        HighlightExtras.order: 0,
      },
    );
    expect(c.extras['highlightId'], 'h1');
    expect(c.extras['highlightTitle'], 'Trip');
    expect(c.extras['highlightOrder'], 0);
  });
}
