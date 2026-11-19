// QA (independent) tests for the T-010 port change.
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:test/test.dart';

String describe(GalleryStoreException e) => switch (e) {
  GalleryPermissionDenied() => 'permission',
  GalleryStorageFull() => 'full',
  GalleryWriteFailed(:final code) => 'failed:$code',
};

void main() {
  test('GalleryStoreException is a DomainException; switch is exhaustive', () {
    const all = <GalleryStoreException>[
      GalleryPermissionDenied(),
      GalleryStorageFull(),
      GalleryWriteFailed('IO_ERROR'),
    ];
    expect(all.map(describe), ['permission', 'full', 'failed:IO_ERROR']);
    for (final e in all) {
      expect(e, isA<DomainException>());
      expect(e, isA<Exception>());
    }
  });

  test('codes and toString carry no path or URI', () {
    expect(const GalleryPermissionDenied().code, 'PERMISSION_DENIED');
    expect(const GalleryStorageFull().code, 'STORAGE_FULL');
    expect(const GalleryWriteFailed('X').toString(), 'GalleryWriteFailed(X)');
  });

  test('FakeGalleryStore failure helpers fire once and then recover', () async {
    final fake = FakeGalleryStore();
    Future<void> save() => fake.save(
      sourcePath: '/x',
      relativeDir: 'u',
      displayName: 'n.jpg',
      mime: 'image/jpeg',
    );
    fake.failNextSaveWithStorageFull();
    await expectLater(save(), throwsA(isA<GalleryStorageFull>()));
    fake.failNextSaveWithPermissionDenied();
    await expectLater(save(), throwsA(isA<GalleryPermissionDenied>()));
    fake.failNextSaveWithWriteFailed('X');
    await expectLater(
      save(),
      throwsA(isA<GalleryWriteFailed>().having((e) => e.code, 'code', 'X')),
    );
    await save();
    expect(fake.files, hasLength(1));
    expect(fake.saved, hasLength(1), reason: 'failed saves are not recorded');
    fake.failNextDelete(const GalleryPermissionDenied());
    final uri = fake.files.single.uri;
    await expectLater(
      fake.delete(uri),
      throwsA(isA<GalleryPermissionDenied>()),
    );
    expect(await fake.exists(uri), isTrue, reason: 'failed delete keeps file');
    expect(await fake.delete(uri), isTrue);
  });
}
