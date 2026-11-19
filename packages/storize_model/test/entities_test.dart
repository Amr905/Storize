import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

RemoteMedia media({
  int index = 0,
  MediaType type = MediaType.photo,
  String url = 'https://cdn.example.test/a.jpg',
  int width = 1080,
  int height = 1920,
  Duration? duration,
}) => RemoteMedia(
  index: index,
  type: type,
  url: url,
  width: width,
  height: height,
  duration: duration,
);

RemoteContent content({
  String remoteId = '3245',
  List<RemoteMedia>? slides,
  Map<String, Object?> extras = const {},
  String? caption = 'hello',
  DateTime? postedAt,
}) => RemoteContent(
  remoteId: remoteId,
  kind: ContentKind.post,
  postedAt: postedAt ?? DateTime.utc(2026, 11, 19, 10, 15),
  slides: slides ?? [media()],
  extras: extras,
  caption: caption,
  shortcode: 'SAMPLE1',
  postType: PostType.carousel,
);

void main() {
  group('RemoteUser', () {
    test('equal fields are equal and hash alike', () {
      const a = RemoteUser(remoteUserId: '1', username: 'sample_user');
      const b = RemoteUser(remoteUserId: '1', username: 'sample_user');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('each field affects equality', () {
      const base = RemoteUser(
        remoteUserId: '1',
        username: 'sample_user',
        displayName: 'Sample',
        avatarUrl: 'https://cdn.example.test/p.jpg',
      );
      expect(
        base,
        isNot(
          const RemoteUser(
            remoteUserId: '2',
            username: 'sample_user',
            displayName: 'Sample',
            avatarUrl: 'https://cdn.example.test/p.jpg',
          ),
        ),
      );
      expect(
        base,
        isNot(
          const RemoteUser(
            remoteUserId: '1',
            username: 'other',
            displayName: 'Sample',
            avatarUrl: 'https://cdn.example.test/p.jpg',
          ),
        ),
      );
      expect(
        base,
        isNot(
          const RemoteUser(
            remoteUserId: '1',
            username: 'sample_user',
            displayName: 'Sample',
            avatarUrl: 'https://cdn.example.test/p.jpg',
            isPrivate: true,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const RemoteUser(
            remoteUserId: '1',
            username: 'sample_user',
            displayName: 'Sample',
            avatarUrl: 'https://cdn.example.test/q.jpg',
          ),
        ),
      );
    });

    test('toString omits the signed avatar URL', () {
      const user = RemoteUser(
        remoteUserId: '1',
        username: 'sample_user',
        avatarUrl: 'https://cdn.example.test/p.jpg?oh=SECRETSIG',
      );
      expect(user.toString(), isNot(contains('SECRETSIG')));
      expect(user.toString(), contains('sample_user'));
    });
  });

  group('RemoteMedia', () {
    test('equal fields are equal and hash alike', () {
      expect(
        media(type: MediaType.video, duration: const Duration(seconds: 9)),
        media(type: MediaType.video, duration: const Duration(seconds: 9)),
      );
      expect(
        media(duration: const Duration(seconds: 9)).hashCode,
        media(duration: const Duration(seconds: 9)).hashCode,
      );
    });

    test('each field affects equality', () {
      expect(media(), isNot(media(index: 1)));
      expect(media(), isNot(media(type: MediaType.video)));
      expect(media(), isNot(media(url: 'https://cdn.example.test/b.jpg')));
      expect(media(), isNot(media(width: 1)));
      expect(media(), isNot(media(height: 1)));
      expect(media(), isNot(media(duration: Duration.zero)));
    });

    test('toString redacts the signed URL', () {
      final m = media(url: 'https://cdn.example.test/a.mp4?oe=SECRETSIG');
      expect(m.toString(), isNot(contains('SECRETSIG')));
      expect(m.toString(), contains('<redacted>'));
    });
  });

  group('RemoteContent', () {
    test('equal content is equal and hashes alike', () {
      expect(content(), content());
      expect(content().hashCode, content().hashCode);
    });

    test('slide order matters', () {
      final a = content(slides: [media(), media(index: 1)]);
      final b = content(slides: [media(index: 1), media()]);
      expect(a, isNot(b));
    });

    test('extras compare by content, including nested maps and lists', () {
      final a = content(
        extras: {
          'links': <Object?>[
            <String, Object?>{'url': 'x', 'n': 1},
          ],
        },
      );
      final b = content(
        extras: {
          'links': <Object?>[
            <String, Object?>{'url': 'x', 'n': 1},
          ],
        },
      );
      final c = content(
        extras: {
          'links': <Object?>[
            <String, Object?>{'url': 'x', 'n': 2},
          ],
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('each scalar field affects equality', () {
      expect(content(remoteId: '9'), isNot(content()));
      expect(content(caption: 'other'), isNot(content()));
      expect(
        content(postedAt: DateTime.utc(2026)),
        isNot(content()),
      );
    });

    test('lists and maps are unmodifiable, including nested values', () {
      final slides = [media()];
      final extras = <String, Object?>{
        'links': <Object?>[1, 2],
      };
      final c = content(slides: slides, extras: extras);

      slides.add(media(index: 1));
      extras['other'] = 1;

      expect(c.slides, hasLength(1));
      expect(c.extras.containsKey('other'), isFalse);
      expect(() => c.slides.add(media(index: 2)), throwsUnsupportedError);
      expect(() => c.extras['x'] = 1, throwsUnsupportedError);
      final links = c.extras['links']! as List<Object?>;
      expect(() => links.add(3), throwsUnsupportedError);
    });

    test('toString omits caption and extras', () {
      final c = content(
        caption: 'PRIVATE CAPTION',
        extras: {'location': 'PRIVATE PLACE'},
      );
      expect(c.toString(), isNot(contains('PRIVATE CAPTION')));
      expect(c.toString(), isNot(contains('PRIVATE PLACE')));
      expect(c.toString(), contains('slides: 1'));
    });
  });

  group('GalleryFile', () {
    const base = GalleryFile(
      uri: 'content://media/external/images/1',
      sizeBytes: 100,
      relativePath: 'Pictures/Storize/sample_user/',
      displayName: 'sample_user_20261119_101503_3245.jpg',
    );

    test('equal fields are equal and hash alike', () {
      const same = GalleryFile(
        uri: 'content://media/external/images/1',
        sizeBytes: 100,
        relativePath: 'Pictures/Storize/sample_user/',
        displayName: 'sample_user_20261119_101503_3245.jpg',
      );
      expect(base, same);
      expect(base.hashCode, same.hashCode);
    });

    test('each field affects equality', () {
      expect(
        base,
        isNot(
          const GalleryFile(
            uri: 'content://media/external/images/2',
            sizeBytes: 100,
            relativePath: 'Pictures/Storize/sample_user/',
            displayName: 'sample_user_20261119_101503_3245.jpg',
          ),
        ),
      );
      expect(
        base,
        isNot(
          const GalleryFile(
            uri: 'content://media/external/images/1',
            sizeBytes: 101,
            relativePath: 'Pictures/Storize/sample_user/',
            displayName: 'sample_user_20261119_101503_3245.jpg',
          ),
        ),
      );
      expect(
        base,
        isNot(
          const GalleryFile(
            uri: 'content://media/external/images/1',
            sizeBytes: 100,
            relativePath: 'Pictures/Storize/other/',
            displayName: 'sample_user_20261119_101503_3245.jpg',
          ),
        ),
      );
      expect(
        base,
        isNot(
          const GalleryFile(
            uri: 'content://media/external/images/1',
            sizeBytes: 100,
            relativePath: 'Pictures/Storize/sample_user/',
            displayName: 'other.jpg',
          ),
        ),
      );
    });
  });
}
