import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

import 'plugin_rules.dart';

/// QA tests for T-010a (independent of the developer's tests).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('storize/media');
  final api = StorizePlatformAndroid(media: channel);

  void mock(Future<Object?> Function(MethodCall) h) =>
      messenger.setMockMethodCallHandler(channel, h);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('QA F-1: mirror equals the JDK set in both directions', () {
    final hidden = File('test/files/fixtures/jdk_hidden_codepoints.txt')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty)
        .map(int.parse)
        .toSet();

    test('every non-surrogate code point: rejected iff the JDK hides it', () {
      const asciiForbidden = r':*?"<>|\/';
      final wrong = <String>[];
      for (var cp = 0; cp <= 0x10FFFF; cp++) {
        if (cp >= 0xD800 && cp <= 0xDFFF) continue;
        if (cp < 0x80 && asciiForbidden.contains(String.fromCharCode(cp))) {
          continue;
        }
        final rejected =
            pluginRejectsDisplayName('a${String.fromCharCode(cp)}b') != null;
        if (rejected != hidden.contains(cp)) wrong.add(cp.toRadixString(16));
      }
      expect(wrong, isEmpty, reason: 'mismatch: $wrong');
    });

    test('Arabic number sign and tag characters are rejected', () {
      for (final cp in [0x0600, 0x0605, 0x06DD, 0xE0001, 0xE007F]) {
        expect(
          pluginRejectsDisplayName('a${String.fromCharCode(cp)}b'),
          isNotNull,
        );
      }
    });
  });

  group('QA storageStats (Dart plugin)', () {
    test('keeps 2^62 values exactly', () async {
      const big = 1 << 62;
      mock((_) async => {'freeBytes': big - 1, 'totalBytes': big});
      final s = await api.storageStats();
      expect(s.freeBytes, big - 1);
      expect(s.totalBytes, big);
    });

    test('doubles are BAD_RESPONSE (no silent truncation)', () async {
      mock((_) async => {'freeBytes': 1.5, 'totalBytes': 10});
      await expectLater(
        api.storageStats(),
        throwsA(
          isA<StorizePlatformException>().having(
            (e) => e.kind,
            'kind',
            StorizePlatformErrorKind.badResponse,
          ),
        ),
      );
    });

    test('negative total and null values are BAD_RESPONSE', () async {
      for (final v in <Map<String, Object?>>[
        {'freeBytes': 1, 'totalBytes': -1},
        {'freeBytes': null, 'totalBytes': 10},
        <String, Object?>{},
      ]) {
        mock((_) async => v);
        await expectLater(
          api.storageStats(),
          throwsA(isA<StorizePlatformException>()),
        );
      }
    });

    test('FINDING: free > total is passed through unclamped on Dart', () async {
      // Kotlin clamps; the Dart side does not re-check. Pin the behaviour so a
      // change is noticed. Callers only compare free with the thresholds.
      mock((_) async => {'freeBytes': 20, 'totalBytes': 10});
      final s = await api.storageStats();
      expect(s.freeBytes, 20);
    });

    test('error text carries no path', () async {
      mock(
        (_) async => throw PlatformException(
          code: 'IO_ERROR',
          message: 'Storage statistics unavailable',
        ),
      );
      try {
        await api.storageStats();
        fail('should throw');
      } on StorizePlatformException catch (e) {
        expect(e.toString(), isNot(contains('/storage')));
      }
    });

    test('bad-response message names only the runtime type', () async {
      mock((_) async => {'freeBytes': '/storage/emulated/0', 'totalBytes': 1});
      try {
        await api.storageStats();
        fail('should throw');
      } on StorizePlatformException catch (e) {
        expect(e.toString(), isNot(contains('/storage')));
      }
    });

    test('PluginStorageInfo makes one native call per read (two reads, '
        'not an atomic pair)', () async {
      var n = 0;
      mock((_) async {
        n++;
        return {'freeBytes': n, 'totalBytes': 100};
      });
      final info = PluginStorageInfo(api);
      expect(await info.freeBytes(), 1);
      expect(await info.totalBytes(), 100);
      expect(n, 2);
    });
  });

  group('QA TypeError mapping in PluginGalleryStore', () {
    test(
      'a wrong-typed insert answer is BAD_RESPONSE, not TypeError',
      () async {
        mock((_) async => 42);
        final store = PluginGalleryStore(api);
        await expectLater(
          store.save(
            sourcePath: '/tmp/x.jpg',
            relativeDir: 'a',
            displayName: 'x.jpg',
            mime: 'image/jpeg',
          ),
          throwsA(
            isA<GalleryWriteFailed>().having(
              (e) => e.toString(),
              's',
              isNot(contains('/tmp')),
            ),
          ),
        );
      },
    );
  });
}
