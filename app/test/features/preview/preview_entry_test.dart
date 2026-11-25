import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/preview/preview_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_model/storize_model.dart';

import 'preview_rig.dart';

void main() {
  late AppLocalizations l10n;
  late PreviewRig rig;

  setUp(() => rig = PreviewRig());

  Finder previewButton() =>
      find.widgetWithText(FilledButton, 'Preview', skipOffstage: false);

  group('S-08 Add account', () {
    Future<void> openForm(WidgetTester t) async {
      await pumpPreview(t, rig: rig, initial: '/targets/add', open: null);
      l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
    }

    testWidgets('Preview is next to Add and needs a valid username', (t) async {
      await rig.addAccount();
      await openForm(t);
      await t.pump();
      final button = t.widget<FilledButton>(previewButton());
      expect(button.onPressed, isNull, reason: 'no username yet');
      expect(find.text(l10n.tgtAddAndVerify), findsOneWidget);

      await t.enterText(find.byType(TextField).first, 'a..b');
      await t.pump();
      expect(t.widget<FilledButton>(previewButton()).onPressed, isNull);

      await t.enterText(find.byType(TextField).first, '@Zed');
      await t.pump();
      expect(t.widget<FilledButton>(previewButton()).onPressed, isNotNull);
    });

    testWidgets('Preview opens the preview of the typed username', (t) async {
      await rig.addAccount();
      rig.script();
      await openForm(t);
      await t.enterText(find.byType(TextField).first, '@Zed');
      await t.pump();
      await t.ensureVisible(previewButton());
      await t.tap(previewButton());
      await settleAsync(t);
      expect(find.byType(PreviewPage), findsOneWidget);
      expect(find.text('Zed Example'), findsOneWidget);
      expect(rig.fake.callsTo('resolveUser').single.args.single, 'zed');
      // Nothing was added by looking.
      expect(await t.runAsync(() => rig.targets.watchAll().first), isEmpty);
    });

    testWidgets('Preview is disabled while the session is not active', (
      t,
    ) async {
      await openForm(t); // no login account
      await t.enterText(find.byType(TextField).first, 'zed');
      await t.pump();
      expect(t.widget<FilledButton>(previewButton()).onPressed, isNull);
    });
  });

  group('S-09 Account detail', () {
    testWidgets('Preview & save opens the preview of this target', (t) async {
      await rig.addAccount();
      final target = await rig.addTarget('zed');
      rig
        ..script()
        ..fake.queueMedia(List<int>.filled(8, 1));
      await pumpPreview(
        t,
        rig: rig,
        initial: '/targets/${target.id}',
        open: null,
      );
      l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
      final action = find.text(l10n.prvPreviewAction);
      await t.ensureVisible(action);
      await t.tap(action);
      await settleAsync(t);
      expect(find.byType(PreviewPage), findsOneWidget);
      expect(find.text('@zed'), findsWidgets);

      // Saving from here uses the tracked target: no second target appears.
      await t.tap(find.byKey(const ValueKey('prv-item-story:s2')));
      await t.pump();
      await t.tap(find.text(l10n.prvSaveSelected(1)));
      await settleAsync(t);
      final all = (await t.runAsync(() => rig.targets.watchAll().first))!;
      expect(all, hasLength(1));
      expect(all.single.status, TargetStatus.active);
      expect(rig.gallery.files, hasLength(1));
    });

    testWidgets('the action is disabled without an active session', (t) async {
      final target = await rig.addTarget('zed');
      await pumpPreview(
        t,
        rig: rig,
        initial: '/targets/${target.id}',
        open: null,
      );
      l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
      final button = find.widgetWithText(
        FilledButton,
        l10n.prvPreviewAction,
        skipOffstage: false,
      );
      expect(t.widget<FilledButton>(button).onPressed, isNull);
    });
  });
}
