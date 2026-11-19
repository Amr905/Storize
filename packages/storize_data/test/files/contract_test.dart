import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_domain/testing.dart';

import 'fake_native_media.dart';
import 'gallery_store_contract.dart';
import 'media_cache_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  galleryStoreContract('PluginGalleryStore', () async {
    return PluginGalleryStore(FakeNativeMedia().api);
  });
  galleryStoreContract('FakeGalleryStore', () async => FakeGalleryStore());

  mediaCacheContract('FileMediaCache', () async {
    final root = Directory.systemTemp.createTempSync('storize_cc_');
    addTearDown(() => root.deleteSync(recursive: true));
    final cache = FileMediaCache(
      cacheDir: () async => Directory('${root.path}/cache'),
      filesDir: () async => Directory('${root.path}/files'),
    );
    File fileOf(String sub) => File(sub);
    return CacheHarness(
      cache: cache,
      partBytes: (id) async {
        final f = fileOf('${root.path}/cache/part/$id.part');
        return f.existsSync() ? f.readAsBytesSync() : null;
      },
      thumbBytes: (id) async {
        final f = fileOf('${root.path}/files/thumbs/$id.webp');
        return f.existsSync() ? f.readAsBytesSync() : null;
      },
    );
  });
  mediaCacheContract('FakeMediaCache', () async {
    final cache = FakeMediaCache();
    return CacheHarness(
      cache: cache,
      partBytes: (id) async => cache.partBytes(id),
      thumbBytes: (id) async => cache.thumbnailBytes(id),
    );
  });
}
