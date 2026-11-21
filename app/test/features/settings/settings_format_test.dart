import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/settings/settings_format.dart';
import 'package:storize_app/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('intervals show minutes below an hour and hours otherwise', () {
    expect(intervalLabel(l10n, 15), '15 min');
    expect(intervalLabel(l10n, 30), '30 min');
    expect(intervalLabel(l10n, 60), '1 h');
    expect(intervalLabel(l10n, 1440), '24 h');
  });

  test('byte sizes pick the unit and keep one decimal', () {
    expect(formatBytes(l10n, 500), '500 B');
    expect(formatBytes(l10n, 2 * 1024), '2.0 KB');
    expect(formatBytes(l10n, 512 * 1024 * 1024), '512.0 MB');
    expect(formatBytes(l10n, 3 * 1024 * 1024 * 1024), '3.0 GB');
  });

  test('retention days accept whole numbers 1 to 3650 only', () {
    expect(parseRetentionDays('1'), 1);
    expect(parseRetentionDays(' 3650 '), 3650);
    expect(parseRetentionDays('0'), isNull);
    expect(parseRetentionDays('3651'), isNull);
    expect(parseRetentionDays('1.5'), isNull);
    expect(parseRetentionDays(''), isNull);
  });
}
