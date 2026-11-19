import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/router/deep_link.dart';
import 'package:storize_model/storize_model.dart';

DeepLink? p(String uri) => DeepLink.parse(Uri.parse(uri));

void main() {
  group('DeepLink.parse', () {
    test('story', () {
      final link = p('storize://story/42');
      expect(link, isA<StoryLink>());
      expect((link! as StoryLink).contentId, 42);
      expect(link.location, '/story/42');
    });

    test('post', () {
      final link = p('storize://post/7');
      expect(link, isA<PostLink>());
      expect(link!.location, '/post/7');
    });

    test('account', () {
      expect(p('storize://account'), isA<AccountLink>());
      expect(p('storize://account')!.location, '/account');
    });

    test('library with filters', () {
      final link = p('storize://library?kind=posts&target=5')! as LibraryLink;
      expect(link.kind, ContentKind.post);
      expect(link.targetId, 5);
      expect(link.location, '/library?kind=posts&target=5');
      expect(
        (p('storize://library?kind=stories')! as LibraryLink).kind,
        ContentKind.story,
      );
    });

    test('library ignores invalid filters', () {
      final link = p('storize://library?kind=reels&target=abc')! as LibraryLink;
      expect(link.kind, isNull);
      expect(link.targetId, isNull);
      expect(link.location, '/library');
    });

    test('settings and settings/storage', () {
      expect(
        p('storize://settings/storage')!.location,
        '/settings?section=storage',
      );
      expect(p('storize://settings')!.location, '/settings');
    });

    for (final bad in [
      'storize://story/abc',
      'storize://story/-3',
      'storize://story/0',
      'storize://story/+5',
      'storize://story/1.5',
      'storize://story/',
      'storize://story',
      'storize://story/1/2',
      'storize://story/99999999999999999999',
      'storize://post/x',
      'storize://account/extra',
      'storize://settings/other',
      'storize://nothing',
      'storize://',
    ]) {
      test('invalid "$bad" falls back to the Library', () {
        final link = p(bad);
        expect(link, isA<LibraryLink>());
        expect(link!.location, '/library');
      });
    }

    test('other schemes are not deep links', () {
      expect(p('https://story/42'), isNull);
      expect(p('/story/42'), isNull);
    });
  });

  test('parseId accepts only positive digit strings', () {
    expect(parseId('12'), 12);
    expect(parseId(null), isNull);
    expect(parseId('0'), isNull);
    expect(parseId(' 1'), isNull);
  });
}
