import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Shared behaviour of every `GalleryStore`: real and fake.
void galleryStoreContract(
  String label,
  Future<GalleryStore> Function() create,
) {
  group('GalleryStore contract: $label', () {
    late Directory tmp;
    late GalleryStore store;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('storize_contract_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      store = await create();
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
  });
}
