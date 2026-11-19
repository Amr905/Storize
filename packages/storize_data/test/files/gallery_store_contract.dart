import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

enum GalleryFailure { permissionDenied, storageFull, other }

/// A store plus a way to make its next call fail the given way.
class GalleryHarness {
  GalleryHarness({
    required this.store,
    required this.failNextSave,
    required this.failNextDelete,
  });
  final GalleryStore store;
  final void Function(GalleryFailure failure) failNextSave;
  final void Function(GalleryFailure failure) failNextDelete;
}

/// Shared behaviour of every `GalleryStore`: real and fake.
void galleryStoreContract(
  String label,
  Future<GalleryHarness> Function() create,
) {
  group('GalleryStore contract: $label', () {
    late Directory tmp;
    late GalleryHarness harness;
    late GalleryStore store;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('storize_contract_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      harness = await create();
      store = harness.store;
    });

    String source(int n, [String name = 's.part']) {
      final f = File('${tmp.path}/$name')..writeAsBytesSync(List.filled(n, 1));
      return f.path;
    }

    Future<GalleryFile> save(String path, [String name = 'n.jpg']) =>
        store.save(
          sourcePath: path,
          relativeDir: 'nour_k',
          displayName: name,
          mime: 'image/jpeg',
        );

    test('save -> exists -> size -> delete lifecycle', () async {
      final path = source(33);
      final file = await save(path);
      expect(await store.exists(file.uri), isTrue);
      expect(await store.size(file.uri), 33);
      expect(file.sizeBytes, 33);
      expect(await store.delete(file.uri), isTrue);
      expect(await store.exists(file.uri), isFalse);
      expect(await store.size(file.uri), isNull);
    });

    test('delete is false when the file is already gone', () async {
      final file = await save(source(1));
      expect(await store.delete(file.uri), isTrue);
      expect(await store.delete(file.uri), isFalse);
    });

    test('each save gets its own URI and the source stays', () async {
      final path = source(4);
      final a = await save(path, 'a.jpg');
      final b = await save(path, 'b.jpg');
      expect(a.uri, isNot(b.uri));
      expect(File(path).existsSync(), isTrue);
    });

    test('result names the folder and the file', () async {
      final file = await save(source(2));
      expect(file.relativePath, contains('nour_k'));
      expect(file.displayName, contains('n'));
      expect(file.sizeBytes, 2);
    });

    test('deleting one file leaves the others', () async {
      final a = await save(source(1), 'a.jpg');
      final b = await save(source(1), 'b.jpg');
      await store.delete(a.uri);
      expect(await store.exists(b.uri), isTrue);
    });

    group('errors', () {
      test('save: permission denied is a typed exception', () async {
        harness.failNextSave(GalleryFailure.permissionDenied);
        await expectLater(
          save(source(1)),
          throwsA(isA<GalleryPermissionDenied>()),
        );
      });

      test('save: storage full is a typed exception', () async {
        harness.failNextSave(GalleryFailure.storageFull);
        await expectLater(save(source(1)), throwsA(isA<GalleryStorageFull>()));
      });

      test('save: any other failure is GalleryWriteFailed', () async {
        harness.failNextSave(GalleryFailure.other);
        await expectLater(
          save(source(1)),
          throwsA(
            isA<GalleryWriteFailed>().having((e) => e.code, 'code', isNotEmpty),
          ),
        );
      });

      test('all three are GalleryStoreException and DomainException', () {
        const all = <GalleryStoreException>[
          GalleryPermissionDenied(),
          GalleryStorageFull(),
          GalleryWriteFailed('X'),
        ];
        for (final e in all) {
          expect(e, isA<DomainException>());
          // Exhaustive: compile error if a subtype is added and not handled.
          final label = switch (e) {
            GalleryPermissionDenied() => 'p',
            GalleryStorageFull() => 's',
            GalleryWriteFailed() => 'w',
          };
          expect(label, isNotEmpty);
        }
      });

      test('a failed save stores nothing and the next save works', () async {
        harness.failNextSave(GalleryFailure.storageFull);
        await expectLater(save(source(1)), throwsA(isA<GalleryStorageFull>()));
        final file = await save(source(2));
        expect(await store.exists(file.uri), isTrue);
      });

      test('delete: permission denied is typed and keeps the file', () async {
        final file = await save(source(1));
        harness.failNextDelete(GalleryFailure.permissionDenied);
        await expectLater(
          store.delete(file.uri),
          throwsA(isA<GalleryPermissionDenied>()),
        );
        expect(await store.exists(file.uri), isTrue);
        expect(await store.delete(file.uri), isTrue);
      });

      test('error text carries no path', () async {
        harness.failNextSave(GalleryFailure.other);
        try {
          await save(source(1));
          fail('should throw');
        } on GalleryStoreException catch (e) {
          expect(e.toString(), isNot(contains(tmp.path)));
        }
      });
    });
  });
}
