// QA (independent) adversarial tests for T-010. Added by the QA engineer.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

import 'fake_native_media.dart';
import 'plugin_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final at = DateTime.utc(2026, 3, 7, 4, 5, 9);

  String name(String user, {String id = '1', int? slide, String ext = 'jpg'}) =>
      displayNameFor(
        username: user,
        postedAt: at,
        remoteId: id,
        slideIndex: slide,
        ext: ext,
      );

  group('QA mirror drift vs the JDK (Cc, Cf, Zl, Zp)', () {
    // fixtures/jdk_hidden_codepoints.txt was generated with
    // Character.getType(cp) in {CONTROL, FORMAT, LINE_SEPARATOR,
    // PARAGRAPH_SEPARATOR}, the exact test InputValidation.kt applies.
    final cps = File('test/files/fixtures/jdk_hidden_codepoints.txt')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty)
        .map(int.parse)
        .toList();

    test('fixture is non-empty', () => expect(cps.length, greaterThan(200)));

    test('plugin_rules.dart rejects every code point the JDK hides', () {
      final missed = [
        for (final cp in cps)
          if (pluginRejectsDisplayName('a${String.fromCharCode(cp)}b') == null)
            cp.toRadixString(16),
      ];
      expect(missed, isEmpty, reason: 'mirror accepts: $missed');
    });

    test('displayNameFor and relativeDirFor strip every hidden code point', () {
      final bad = <String>[];
      for (final cp in cps) {
        final s = 'a${String.fromCharCode(cp)}b';
        final n = name(s, id: s);
        final d = relativeDirFor(s);
        if (pluginRejectsDisplayName(n) != null ||
            pluginRejectsRelativeDir(d) != null) {
          bad.add(cp.toRadixString(16));
        }
      }
      expect(bad, isEmpty);
    });
  });

  group('QA hostile names always satisfy the plugin rules', () {
    final hostile = <String>[
      '',
      '.',
      '..',
      '....',
      '~',
      '~~~',
      '~/x',
      '.nomedia',
      'CON',
      'NUL',
      'a${String.fromCharCode(0x202E)}b', // RTL override
      '‏‏x', // RLM
      '؜x',
      '\uD800', // lone high surrogate
      '\uDC00', // lone low surrogate
      'x\uD83D', // trailing lone high
      '\uDE00x',
      '😀' * 80, // 160 units
      '日本語' * 60,
      'a' * 1000,
      ' ',
      '   x   ',
      'x.',
      'x. . ',
      '\x00',
      '%2e%2e',
      'a∕b', // division slash
      'ａｂｃ',
    ];
    for (final h in hostile) {
      test('hostile ${jsonEncode(h)}', () {
        final dir = relativeDirFor(h);
        expect(pluginRejectsRelativeDir(dir), isNull, reason: dir);
        expect(dir.contains('/'), isFalse);
        final n = name(h, id: h, slide: 3);
        expect(pluginRejectsDisplayName(n), isNull, reason: n);
        // A well-formed UTF-16 string comes out (encodable as UTF-8 and back).
        expect(utf8.decode(utf8.encode(n)), n);
        expect(utf8.decode(utf8.encode(dir)), dir);
        expect(dir, isNot(startsWith('~')));
      });
    }

    test('fuzz: 3000 random strings over all planes and lone surrogates', () {
      final r = Random(10);
      for (var i = 0; i < 3000; i++) {
        final units = <int>[];
        final len = r.nextInt(150);
        for (var j = 0; j < len; j++) {
          switch (r.nextInt(5)) {
            case 0:
              units.add(0xD800 + r.nextInt(0x800)); // any surrogate unit
            case 1:
              units.add(r.nextInt(0xFFFF)); // BMP
            case 2:
              units.add(0x2E + r.nextInt(3)); // . / 0
            case 3:
              units.addAll([0xD83D, 0xDE00]);
            default:
              units.add(0x20 + r.nextInt(0x5F));
          }
        }
        final s = String.fromCharCodes(units);
        final dir = relativeDirFor(s);
        final n = name(s, id: s, slide: i);
        expect(pluginRejectsRelativeDir(dir), isNull, reason: '$units -> $dir');
        expect(pluginRejectsDisplayName(n), isNull, reason: '$units -> $n');
      }
    });

    test('dots-only and tilde-only inputs have stable fallbacks', () {
      expect(relativeDirFor(''), 'unknown');
      expect(relativeDirFor('.'), isNotEmpty);
      expect(relativeDirFor('~'), '_');
      expect(relativeDirFor('~~~'), '_~~');
      expect(relativeDirFor('.nomedia'), '_nomedia');
      expect(name('', id: ''), 'user_20260307_040509_0.jpg');
    });

    test('no collision between folder and hidden names', () {
      expect(relativeDirFor('.nomedia'), isNot('.nomedia'));
      expect(relativeDirFor('..'), isNot(contains('.')));
    });

    test('KNOWN GAP: names are length-limited in chars, not UTF-8 bytes', () {
      // InputValidation.kt counts UTF-16 units (255 / 100), but ext4 and f2fs
      // limit a name to 255 BYTES. Real Instagram names are ASCII, so this
      // only bites a hostile or non-ASCII remote ID.
      final n = name('日' * 64, id: '本' * 64, slide: 1);
      expect(pluginRejectsDisplayName(n), isNull);
      expect(utf8.encode(n).length, greaterThan(255));
      final d = relativeDirFor('日' * 100);
      expect(utf8.encode(d).length, greaterThan(255));
    });

    test('DESIRED: name stays within 255 UTF-8 bytes', () {
      final n = name('日' * 64, id: '本' * 64, slide: 1);
      expect(utf8.encode(n).length, lessThanOrEqualTo(255));
    }, skip: 'F-1 minor: displayNameFor caps characters, not bytes');
  });

  group('QA determinism and format', () {
    test('local and UTC inputs give the same name', () {
      final utc = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final local = utc.toLocal();
      expect(name('u'), name('u'));
      expect(
        displayNameFor(
          username: 'u',
          postedAt: local,
          remoteId: '1',
          ext: 'jpg',
        ),
        displayNameFor(username: 'u', postedAt: utc, remoteId: '1', ext: 'jpg'),
      );
    });

    test('milliseconds and microseconds are ignored; fields zero padded', () {
      final t = DateTime.utc(2026, 1, 2, 3, 4, 5, 999, 999);
      expect(
        displayNameFor(username: 'u', postedAt: t, remoteId: '1', ext: 'jpg'),
        'u_20260102_030405_1.jpg',
      );
      expect(
        displayNameFor(
          username: 'u',
          postedAt: DateTime.utc(7),
          remoteId: '1',
          ext: 'jpg',
        ),
        'u_00070101_000000_1.jpg',
      );
    });

    test('slide 0 is present, null is absent; ext sanitised', () {
      expect(name('u', slide: 0), 'u_20260307_040509_1_0.jpg');
      expect(name('u'), 'u_20260307_040509_1.jpg');
      expect(name('u', ext: 'JPG'), endsWith('.jpg'));
      expect(name('u', ext: 'tar.gz'), endsWith('.targz'));
    });

    test('sanitising can map two usernames to one name (by design)', () {
      expect(name('a/b'), name('a_b'));
    });
  });

  group('QA FileMediaCache', () {
    late Directory root;
    late FileMediaCache cache;
    Directory part() => Directory('${root.path}/cache/part');
    setUp(() {
      root = Directory.systemTemp.createTempSync('qa_t010_');
      addTearDown(() => root.deleteSync(recursive: true));
      cache = FileMediaCache(
        cacheDir: () async => Directory('${root.path}/cache'),
        filesDir: () async => Directory('${root.path}/files'),
      );
    });

    test('ids are ints: extreme and negative ids stay inside part/', () async {
      for (final id in [-1, 0, 1 << 62, -(1 << 62)]) {
        await cache.append(id, Stream.value([1, 2, 3]));
        final p = await cache.completedPath(id);
        expect(File(p).parent.path, part().path);
        expect(await cache.partialLength(id), 3);
        await cache.writeThumbnail(id, [9]);
      }
      final thumbs = Directory('${root.path}/files/thumbs').listSync();
      for (final e in thumbs) {
        expect(e.parent.path, '${root.path}/files/thumbs');
      }
      // Nothing was written outside cache/part and files/thumbs.
      final top = root
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path);
      for (final p in top) {
        expect(
          p.startsWith('${root.path}/cache/part/') ||
              p.startsWith('${root.path}/files/thumbs/'),
          isTrue,
          reason: p,
        );
      }
    });

    test(
      'resume after a failed stream: length is the written prefix',
      () async {
        Stream<List<int>> broken() async* {
          yield List.filled(10, 1);
          yield List.filled(5, 2);
          throw const FileSystemException('boom');
        }

        await expectLater(cache.append(7, broken()), throwsA(anything));
        expect(await cache.partialLength(7), 15);
        await cache.append(7, Stream.value(List.filled(4, 3)));
        expect(await cache.partialLength(7), 19);
        final bytes = File(await cache.completedPath(7)).readAsBytesSync();
        expect(bytes.sublist(0, 10), List.filled(10, 1));
        expect(bytes.sublist(10, 15), List.filled(5, 2));
        expect(bytes.sublist(15), List.filled(4, 3));
      },
    );

    test('empty stream creates an empty part and length 0', () async {
      await cache.append(3, const Stream.empty());
      expect(await cache.partialLength(3), 0);
      expect(File(await cache.completedPath(3)).existsSync(), isTrue);
    });

    test('concurrent appends to one id lose data (unsupported)', () async {
      Stream<List<int>> chunks(int v) => Stream.fromIterable([
        for (var i = 0; i < 50; i++) List.filled(100, v),
      ]);
      await Future.wait([
        cache.append(5, chunks(1)),
        cache.append(5, chunks(2)),
      ]);
      final len = await cache.partialLength(5);
      // Observed: 5000 (half the bytes overwritten). F-2 minor, class doc says
      // concurrent appends are unsupported. File is never longer than the sum.
      expect(len, inInclusiveRange(5000, 10000));
    });

    test('discard then partialLength is 0; discard twice is fine', () async {
      await cache.append(1, Stream.value([1]));
      await cache.discard(1);
      await cache.discard(1);
      expect(await cache.partialLength(1), 0);
      await expectLater(cache.completedPath(1), throwsStateError);
    });

    test('cleanupOrphans removes only *.part files, keeps keepIds', () async {
      await part().create(recursive: true);
      File('${part().path}/1.part').writeAsBytesSync([1]);
      File('${part().path}/2.part').writeAsBytesSync([1]);
      File('${part().path}/notes.txt').writeAsBytesSync([1]);
      File('${part().path}/3.part.tmp').writeAsBytesSync([1]);
      File('${part().path}/junk.part').writeAsBytesSync([1]);
      Directory('${part().path}/dir.part').createSync();
      File('${part().path}/dir.part/inner.part').writeAsBytesSync([1]);
      final n = await cache.cleanupOrphans({2});
      expect(n, 2); // 1.part and junk.part
      final left = part()
          .listSync()
          .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toSet();
      expect(left, {'2.part', 'notes.txt', '3.part.tmp', 'dir.part'});
      expect(File('${part().path}/dir.part/inner.part').existsSync(), isTrue);
    });

    test('cleanupOrphans never follows or deletes through symlinks', () async {
      final outside = Directory('${root.path}/outside')..createSync();
      final victim = File('${outside.path}/victim.part')..writeAsBytesSync([1]);
      final victimDirFile = File('${outside.path}/inner.part')
        ..writeAsBytesSync([1]);
      await part().create(recursive: true);
      Link('${part().path}/9.part').createSync(victim.path);
      Link('${part().path}/linkdir.part').createSync(outside.path);
      final removed = await cache.cleanupOrphans({});
      expect(victim.existsSync(), isTrue, reason: 'link target deleted');
      expect(victimDirFile.existsSync(), isTrue);
      expect(outside.existsSync(), isTrue);
      expect(removed, 0);
      expect(Link('${part().path}/9.part').existsSync(), isTrue);
    });

    test('cleanupOrphans on a missing directory is 0', () async {
      expect(await cache.cleanupOrphans({}), 0);
    });

    test(
      'failed thumbnail write keeps the old thumbnail and leaves no temp',
      () async {
        await cache.writeThumbnail(4, [1, 2, 3]);
        final thumbs = Directory('${root.path}/files/thumbs');
        // Force the temp write to fail: a directory sits at the temp path.
        Directory('${thumbs.path}/4.webp.tmp').createSync();
        await expectLater(cache.writeThumbnail(4, [9, 9]), throwsA(anything));
        expect(File('${thumbs.path}/4.webp').readAsBytesSync(), [1, 2, 3]);
      },
    );

    test('failed rename keeps old target; temp is removed', () async {
      final thumbs = Directory('${root.path}/files/thumbs')
        ..createSync(recursive: true);
      // A directory at the target makes rename(file -> dir) fail.
      Directory('${thumbs.path}/6.webp').createSync();
      await expectLater(cache.writeThumbnail(6, [1]), throwsA(anything));
      expect(File('${thumbs.path}/6.webp.tmp').existsSync(), isFalse);
      expect(Directory('${thumbs.path}/6.webp').existsSync(), isTrue);
    });

    test(
      'thumbnail overwrite replaces content and returns files/thumbs path',
      () async {
        final p1 = await cache.writeThumbnail(8, [1]);
        final p2 = await cache.writeThumbnail(8, [2, 2]);
        expect(p1, p2);
        expect(p2, '${root.path}/files/thumbs/8.webp');
        expect(File(p2).readAsBytesSync(), [2, 2]);
        expect(Directory('${root.path}/files/thumbs').listSync().length, 1);
      },
    );
  });

  group('QA PluginGalleryStore error mapping', () {
    late FakeNativeMedia native;
    late PluginGalleryStore store;
    late Directory tmp;
    late String src;
    const secret = '/data/user/0/com.amr905.storize/cache/part/12.part?sig=abc';
    setUp(() {
      native = FakeNativeMedia();
      store = PluginGalleryStore(native.api);
      tmp = Directory.systemTemp.createTempSync('qa_t010g_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      src = (File('${tmp.path}/s')..writeAsBytesSync([1, 2])).path;
    });

    Future<Object?> catching(Future<Object?> Function() f) async {
      try {
        await f();
      } on Object catch (e) {
        return e;
      }
      return null;
    }

    const codes = [
      'INVALID_ARGUMENT',
      'UNSUPPORTED_MIME',
      'SOURCE_NOT_FOUND',
      'PERMISSION_DENIED',
      'STORAGE_FULL',
      'IO_ERROR',
      'INSERT_FAILED',
      'THUMBNAIL_FAILED',
      'UNAVAILABLE',
      'BAD_RESPONSE',
      'UNKNOWN',
      'SOMETHING_NEW',
      '',
    ];

    for (final code in codes) {
      test('save maps $code and leaks nothing', () async {
        native.failNext = PlatformException(code: code, message: secret);
        final e = await catching(
          () => store.save(
            sourcePath: src,
            relativeDir: 'u',
            displayName: 'n.jpg',
            mime: 'image/jpeg',
          ),
        );
        expect(e, isA<GalleryStoreException>());
        final g = e! as GalleryStoreException;
        switch (code) {
          case 'PERMISSION_DENIED':
            expect(g, isA<GalleryPermissionDenied>());
          case 'STORAGE_FULL':
            expect(g, isA<GalleryStorageFull>());
          default:
            expect(g, isA<GalleryWriteFailed>());
            expect(g.code, code);
        }
        for (final s in [g.toString(), g.code]) {
          expect(s, isNot(contains('/data')));
          expect(s, isNot(contains('sig=')));
          expect(s, isNot(contains('content://')));
        }
      });
    }

    for (final method in ['delete', 'exists', 'size']) {
      for (final code in codes) {
        test('$method maps $code', () async {
          native.failNext = PlatformException(code: code, message: secret);
          Future<Object?> call() => switch (method) {
            'delete' => store.delete('content://media/external/images/media/1'),
            'exists' => store.exists('content://media/external/images/media/1'),
            _ => store.size('content://media/external/images/media/1'),
          };
          final r = await catching(call);
          if (code == 'SOURCE_NOT_FOUND') {
            expect(r, anyOf(isNull)); // handled as missing, no throw
          } else {
            expect(r, isA<GalleryStoreException>());
            expect(r.toString(), isNot(contains('/data')));
          }
        });
      }
    }

    test(
      'a wrong-typed native answer becomes GalleryWriteFailed(BAD_RESPONSE)',
      () async {
        // A wrong-typed answer is not a StorizePlatformException.
        native.channel; // ignore: unnecessary_statements
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(native.channel, (_) async => 'junk');
        final e = await catching(
          () => store.save(
            sourcePath: src,
            relativeDir: 'u',
            displayName: 'n.jpg',
            mime: 'image/jpeg',
          ),
        );
        // F-4: the channel cast throws a TypeError; the store maps it.
        expect(e, isA<GalleryWriteFailed>());
        expect((e! as GalleryWriteFailed).code, 'BAD_RESPONSE');
      },
    );

    test(
      'delete/exists/size of a URI Storize does not own (fake native)',
      () async {
        const foreign = 'content://com.android.contacts/contacts/1';
        expect(await store.exists(foreign), isFalse);
        expect(await store.size(foreign), isNull);
        expect(await store.delete(foreign), isFalse);
      },
    );

    test(
      'the real plugin answers INVALID_ARGUMENT for a foreign authority',
      () async {
        // Plugin (UriPolicy) throws INVALID_ARGUMENT; store must not crash with
        // a non-domain exception.
        native.failNext = PlatformException(code: 'INVALID_ARGUMENT');
        final e = await catching(() => store.delete('content://x/1'));
        expect(e, isA<GalleryWriteFailed>());
      },
    );

    test(
      'exists/size may throw GalleryPermissionDenied (port documents it)',
      () async {
        native.failNext = PlatformException(code: 'PERMISSION_DENIED');
        final e = await catching(() => store.exists('content://media/x'));
        // F-4: the port documents the full set for exists/size.
        expect(e, isA<GalleryPermissionDenied>());
      },
    );
  });

  group('QA contract parity real vs fake', () {
    test('KNOWN DIFFERENCE: relativePath shape', () async {
      final dir = Directory.systemTemp.createTempSync('qa_t010p_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/s')..writeAsBytesSync([1]);
      final native = FakeNativeMedia();
      final real = await PluginGalleryStore(native.api).save(
        sourcePath: f.path,
        relativeDir: 'nour_k',
        displayName: 'n.jpg',
        mime: 'image/jpeg',
      );
      final fake = await FakeGalleryStore().save(
        sourcePath: f.path,
        relativeDir: 'nour_k',
        displayName: 'n.jpg',
        mime: 'image/jpeg',
      );
      expect(real.relativePath, 'Pictures/Storize/nour_k/');
      expect(fake.relativePath, 'nour_k'); // finding F-3
    });

    test(
      'KNOWN DIFFERENCE: missing source succeeds in the fake only',
      () async {
        final native = FakeNativeMedia();
        Future<Object?> run(GalleryStore s) async {
          try {
            await s.save(
              sourcePath: '/nonexistent/x.part',
              relativeDir: 'u',
              displayName: 'n.jpg',
              mime: 'image/jpeg',
            );
            return null;
          } on GalleryStoreException catch (e) {
            return e;
          }
        }

        expect(
          await run(PluginGalleryStore(native.api)),
          isA<GalleryWriteFailed>(),
        );
        expect(await run(FakeGalleryStore()), isNull); // finding F-3
      },
    );

    test(
      'KNOWN DIFFERENCE: the fake does not validate names or rename',
      () async {
        final fake = FakeGalleryStore();
        final f = await fake.save(
          sourcePath: '/x',
          relativeDir: '../..',
          displayName: 'a/b',
          mime: 'text/plain',
        );
        expect(f.displayName, 'a/b'); // finding F-3 (minor, by design)
      },
    );
  });
}
