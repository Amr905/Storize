import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/components/thumb_frame.dart';
import 'package:storize_app/ui/ui.dart';

import 'golden_helpers.dart';

/// Independent QA checks for T-024b: wording is byte-identical to the removed
/// `StorizeStrings`, semantics labels survive the move, and missing delegates
/// fail loudly.
void main() {
  late AppLocalizations l10n;
  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('wording is identical to the removed StorizeStrings values', () {
    final expected = <String, String>{
      l10n.statusActive: 'Active',
      l10n.statusChecking: 'Checking',
      l10n.statusPaused: 'Paused',
      l10n.statusNotVisible: 'Not visible',
      l10n.statusUnavailable: 'Unavailable',
      l10n.statusError: 'Error',
      l10n.statusNeedsRelogin: 'Needs re-login',
      l10n.statusRestricted: 'Restricted',
      l10n.categoryOwn: 'Own / client',
      l10n.categoryConsented: 'Consented',
      l10n.categoryPublic: 'Public',
      l10n.bannerFix: 'Fix',
      l10n.bannerReloginTitle: 'Instagram login needs attention',
      l10n.bannerReloginBody: 'Checks are paused.',
      l10n.bannerRestrictedTitle: 'Instagram account restricted',
      l10n.bannerRestrictedBody: 'Checks are paused.',
      l10n.thumbNew: 'new',
      l10n.thumbBroken: "Can't load",
      l10n.thumbSelected: 'selected',
      l10n.stepDone: 'Done',
      l10n.stepPending: 'To do',
      l10n.all: 'All',
      l10n.loading: 'Loading',
      l10n.expand: 'Expand',
      l10n.collapse: 'Collapse',
      l10n.pinDelete: 'Delete',
      l10n.pinBiometric: 'Use biometrics',
      l10n.pinProgress(3, 4): '3 of 4 digits entered',
      l10n.pinCooldown('0:30'): 'Try again in 0:30',
    };
    for (final MapEntry(key: actual, value: want) in expected.entries) {
      expect(actual, want);
    }
  });

  testWidgets('PinPad exposes progress, delete, biometric and cooldown', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        PinPad(
          length: 4,
          filled: 3,
          onDigit: (_) {},
          onBackspace: () {},
          onBiometric: () {},
        ),
        brightness: Brightness.light,
      ),
    );
    expect(find.bySemanticsLabel('3 of 4 digits entered'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);
    expect(find.bySemanticsLabel('Use biometrics'), findsOneWidget);

    await tester.pumpWidget(
      themed(
        PinPad(
          length: 4,
          filled: 0,
          onDigit: (_) {},
          onBackspace: () {},
          cooldown: const Duration(seconds: 30),
        ),
        brightness: Brightness.light,
      ),
    );
    expect(find.text('Try again in 0:30'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('SessionBanner defaults render and keep the Fix action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        Column(
          children: [
            SessionBanner(kind: SessionBannerKind.needsRelogin, onFix: () {}),
            SessionBanner(kind: SessionBannerKind.restricted, onFix: () {}),
          ],
        ),
        brightness: Brightness.light,
      ),
    );
    expect(find.text('Instagram login needs attention'), findsOneWidget);
    expect(find.text('Instagram account restricted'), findsOneWidget);
    expect(find.text('Checks are paused.'), findsNWidgets(2));
    expect(find.text('Fix'), findsNWidgets(2));
    expect(find.bySemanticsLabel(RegExp(r'^Fix$')), findsNWidgets(2));
    handle.dispose();
  });

  testWidgets('StatusBadge, AccountChipRow and ThumbFrame defaults', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        Column(
          children: [
            const StatusBadge(status: StorizeStatus.paused),
            AccountChipRow(
              items: const [],
              selectedIds: const {},
              onChanged: (_) {},
            ),
            const SizedBox(
              width: 100,
              child: ThumbFrame(
                aspectRatio: 1,
                semanticLabel: 'thumb',
                broken: true,
              ),
            ),
          ],
        ),
        brightness: Brightness.light,
      ),
    );
    expect(find.bySemanticsLabel('Paused'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text("Can't load"), findsOneWidget);
    expect(StatusBadge.defaultLabel(l10n, StorizeStatus.error), 'Error');
    expect(CategoryTag.defaultLabel(l10n, CategoryKind.publicFigure), 'Public');
    handle.dispose();
  });

  testWidgets('pumping a default-label widget without delegates fails loudly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StatusBadge(status: StorizeStatus.active)),
    );
    expect(tester.takeException(), isNotNull);
  });
}
