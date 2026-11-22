// T-038: ActivityItem subtitle slot (S-11 gap entry) and the spoken label of
// the AccountChipRow "+N" overflow chip.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

Future<void> _pump(WidgetTester t, Widget child) async {
  await t.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StorizeTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('ActivityItem shows the subtitle under the text', (t) async {
    await _pump(
      t,
      const ActivityItem(
        icon: Icons.warning_amber_rounded,
        tone: ActivityTone.warning,
        time: '09:40',
        text: 'Gap: no checks',
        subtitle: '02:10–09:40',
        actionLabel: 'Fix battery settings',
      ),
    );
    expect(find.text('Gap: no checks'), findsOneWidget);
    expect(find.text('02:10–09:40'), findsOneWidget);
    expect(find.text('Fix battery settings'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('02:10–09:40')).dy,
      greaterThan(t.getTopLeft(find.text('Gap: no checks')).dy),
    );
  });

  testWidgets('ActivityItem without subtitle renders no extra line', (t) async {
    await _pump(
      t,
      const ActivityItem(
        icon: Icons.info_outline_rounded,
        tone: ActivityTone.neutral,
        time: '08:00',
        text: 'Removed before download',
      ),
    );
    expect(find.text('Removed before download'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
  });

  testWidgets('AccountChipRow overflow chip has a spoken label', (t) async {
    await _pump(
      t,
      AccountChipRow(
        items: const [
          AccountChipItem(id: '1', label: '@a'),
          AccountChipItem(id: '2', label: '@b'),
          AccountChipItem(id: '3', label: '@c'),
          AccountChipItem(id: '4', label: '@d'),
        ],
        selectedIds: const {},
        onChanged: (_) {},
        maxVisible: 2,
        onOverflowTap: () {},
      ),
    );
    expect(find.bySemanticsLabel('2 more accounts'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });
}
