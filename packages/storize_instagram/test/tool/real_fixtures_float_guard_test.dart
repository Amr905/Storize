// Guard (T-002 round 2, B2/L1/L2): the committed real fixtures must hold no
// precise floats, no float under a location-typed object, and no
// latest_reel_media outside the documented owner paths.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _root = 'test/fixtures/real';

Iterable<File> _files(String ext) =>
    Directory(
          _root,
        )
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith(ext));

/// Visits every value; reports floats with their location-ness.
void _walk(
  dynamic j,
  String path,
  bool inLocation,
  void Function(String path, dynamic v, bool inLocation) visit,
) {
  if (j is Map) {
    final t = j['__typename'];
    final loc =
        inLocation || (t is String && t.toLowerCase().contains('location'));
    j.forEach((k, v) {
      _walk(v, '$path.$k', loc, visit);
    });
  } else if (j is List) {
    for (final v in j) {
      _walk(v, '$path[]', inLocation, visit);
    }
  } else {
    visit(path, j, inLocation);
  }
}

void main() {
  test('no float has more than 4 decimals; no float under a location', () {
    var locationObjects = 0;
    var floats = 0;
    for (final f in _files('.json')) {
      if (!f.path.contains('/bodies/')) continue;
      final j = jsonDecode(f.readAsStringSync());
      _walk(j, r'$', false, (path, v, loc) {
        if (v is double) {
          floats++;
          final s = v.toString();
          expect(s.contains('e'), isFalse, reason: '${f.path} $path');
          expect(
            s.split('.').last.length,
            lessThanOrEqualTo(4),
            reason: '${f.path} $path',
          );
          expect(loc, isFalse, reason: 'float under location: ${f.path} $path');
        }
      });
      locationObjects += RegExp(
        'Location',
      ).allMatches(f.readAsStringSync()).length;
    }
    expect(floats, greaterThan(0), reason: 'guard needs some floats to check');
    expect(
      locationObjects,
      greaterThan(0),
      reason: 'fixtures must still contain a location-typed object',
    );
  });

  test('no long decimal literal in any fixture file (text grep)', () {
    final long = RegExp(r'\d\.\d{5,}');
    for (final f in _files('')) {
      expect(long.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('latest_reel_media only at the owner paths', () {
    final allowed = {
      r'$.data.user.latest_reel_media',
      r'$.data.key_1.reels_media[].latest_reel_media',
    };
    var kept = 0;
    for (final f in _files('.json')) {
      if (!f.path.contains('/bodies/')) continue;
      _walk(jsonDecode(f.readAsStringSync()), r'$', false, (path, v, _) {
        if (path.endsWith('.latest_reel_media') && v != null) {
          kept++;
          // Story root key keeps its real name via keep_keys.txt.
          final norm = path.replaceFirst(
            r'$.data.xdt_api__v1__feed__reels_media.',
            r'$.data.key_1.',
          );
          expect(allowed, contains(norm), reason: '${f.path} $path');
        }
      });
    }
    expect(kept, 2);
  });
}
