// QA guard (T-002 verification): CDN edge labels must not be committed.
//
// A label such as the first part of "<edge>.fna.fbcdn.net" names the CDN
// point of presence that served the capturer, which hints at their city.
// The Lead decided (2026-11-20) to scrub these from committed fixtures.
// Enabled in T-002 round 2 (the sanitizer now scrubs them).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fixtures contain no CDN edge labels (only generic host labels)',
    () {
      final hostRe = RegExp('<url host=([^ >]+)');
      const generic = {
        'www',
        'i',
        'l',
        'static',
        'scontent',
        'video',
        'instagram',
      };
      final bad = <String>{};
      for (final f in Directory(
        'test/fixtures/real',
      ).listSync(recursive: true).whereType<File>()) {
        for (final m in hostRe.allMatches(f.readAsStringSync())) {
          final labels = m.group(1)!.split('.');
          // Only the label list shape is reported, never the value.
          for (final l in labels) {
            if (RegExp(r'^[a-z]{2,4}\d{1,3}-\d+$').hasMatch(l) ||
                (labels.length > 2 &&
                    !generic.contains(l) &&
                    !{
                      'fna',
                      'fbcdn',
                      'cdninstagram',
                      'net',
                      'com',
                    }.contains(l))) {
              bad.add('${f.path}: edge-label-shaped host label');
            }
          }
        }
      }
      expect(bad, isEmpty);
    },
  );
}
