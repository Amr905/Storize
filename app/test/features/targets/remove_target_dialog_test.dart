import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

import 'target_detail_rig.dart';

/// Opens S-09 for [target], then the overflow menu, then S-10.
Future<AppLocalizations> _openDialog(
  WidgetTester tester,
  DetailRig rig,
  Target target,
) async {
  await pumpDetail(tester, rig: rig, targetId: target.id);
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  await tester.tap(find.byTooltip(l10n.tdtMenuTooltip));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.tdtRemove));
  await tester.pumpAndSettle();
  return l10n;
}

void main() {
  group('S-10 remove dialog (AC6)', () {
    testWidgets('Keep is the default: only the target is removed', (
      tester,
    ) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await rig.addContent(target);
      final l10n = await _openDialog(tester, rig, target);

      expect(find.text(l10n.tdtRemoveTitle('nour_k')), findsOneWidget);
      expect(find.text(l10n.tdtRemoveCounts(1, 0)), findsOneWidget);
      expect(find.text(l10n.tdtRemoveConfirmDelete), findsNothing);

      // A scripted gallery failure that stays unused proves Keep never deletes
      // files. The content rows go with the target (ON DELETE CASCADE).
      rig.gallery.failNextDelete(const GalleryWriteFailed('unused'));
      await tester.tap(find.widgetWithText(PrimaryButton, l10n.tdtRemove));
      await tester.pumpAndSettle();

      expect(await rig.targets.getById(target.id), isNull);
      expect(find.text(l10n.tdtRemovePartial), findsNothing);
      expect(find.text('S-07 stub'), findsOneWidget);
      expect(find.text(l10n.tdtRemoved('nour_k')), findsOneWidget);
    });

    testWidgets('Delete turns the button red and deletes the downloads', (
      tester,
    ) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      final contentId = await rig.addContent(target);
      final l10n = await _openDialog(tester, rig, target);

      await tester.tap(find.text(l10n.tdtRemoveDelete));
      await tester.pumpAndSettle();
      expect(find.text(l10n.tdtRemove), findsNothing);
      final button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, l10n.tdtRemoveConfirmDelete),
      );
      expect(button.destructive, isTrue);

      await tester.tap(
        find.widgetWithText(PrimaryButton, l10n.tdtRemoveConfirmDelete),
      );
      await tester.pumpAndSettle();

      expect(await rig.targets.getById(target.id), isNull);
      expect(await rig.content.getById(contentId), isNull);
    });

    testWidgets('Cancel keeps the target', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      final l10n = await _openDialog(tester, rig, target);

      await tester.tap(find.widgetWithText(StorizeTextButton, l10n.libCancel));
      await tester.pumpAndSettle();

      expect(await rig.targets.getById(target.id), isNotNull);
      expect(find.text(l10n.tdtRemoveTitle('nour_k')), findsNothing);
    });

    testWidgets('a failed file delete keeps the dialog open with a message', (
      tester,
    ) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await rig.addContent(target);
      final l10n = await _openDialog(tester, rig, target);

      rig.gallery.failNextDelete(const GalleryWriteFailed('test'));
      await tester.tap(find.text(l10n.tdtRemoveDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryButton, l10n.tdtRemoveConfirmDelete),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.tdtRemovePartial), findsOneWidget);
      expect(find.text(l10n.tdtRemoveTitle('nour_k')), findsOneWidget);
      expect(await rig.targets.getById(target.id), isNotNull);
    });
  });
}
