import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_filter_sheet.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

/// T-042 AC3: the Highlights filter in S-05 and its repo filter.
void main() {
  final now = DateTime.utc(2026, 11, 21, 12);

  group('LibraryFilters.highlightsOnly', () {
    test('maps to the highlight kind in the repo filter', () {
      final f = LibraryFilters(highlightsOnly: true);
      expect(
        f.toContentFilter(LibraryKind.stories, now).kind,
        ContentKind.highlight,
      );
      expect(
        LibraryFilters.none.toContentFilter(LibraryKind.stories, now).kind,
        ContentKind.story,
      );
    });

    test('counts as an active filter and is part of equality', () {
      expect(LibraryFilters(highlightsOnly: true).isActive, isTrue);
      expect(LibraryFilters.none.isActive, isFalse);
      expect(
        LibraryFilters(highlightsOnly: true),
        isNot(equals(LibraryFilters.none)),
      );
      expect(
        LibraryFilters.none.copyWith(highlightsOnly: true).highlightsOnly,
        isTrue,
      );
    });
  });

  testWidgets('AC3: the Highlights chip returns highlights-only stories', (
    t,
  ) async {
    LibraryFilterResult? result;
    await t.pumpWidget(
      _Host(
        onResult: (r) => result = r,
        kind: LibraryKind.posts,
        filters: LibraryFilters.none,
      ),
    );
    await t.tap(find.byType(ElevatedButton));
    await t.pumpAndSettle();
    final l10n = AppLocalizations.of(
      t.element(find.byType(LibraryFilterSheet)),
    );

    await t.tap(find.byKey(const ValueKey('filter-kind-highlights')));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.libApply));
    await t.pumpAndSettle();

    expect(result?.filters.highlightsOnly, isTrue);
    expect(result?.kind, LibraryKind.stories);
  });

  testWidgets('AC3: choosing Posts clears the Highlights filter', (t) async {
    LibraryFilterResult? result;
    await t.pumpWidget(
      _Host(
        onResult: (r) => result = r,
        kind: LibraryKind.stories,
        filters: LibraryFilters(highlightsOnly: true),
      ),
    );
    await t.tap(find.byType(ElevatedButton));
    await t.pumpAndSettle();
    final l10n = AppLocalizations.of(
      t.element(find.byType(LibraryFilterSheet)),
    );

    await t.tap(find.byKey(const ValueKey('filter-kind-posts')));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.libApply));
    await t.pumpAndSettle();

    expect(result?.filters.highlightsOnly, isFalse);
    expect(result?.kind, LibraryKind.posts);
  });
}

/// Opens the S-05 sheet from a button and reports the Apply result.
class _Host extends StatelessWidget {
  const _Host({
    required this.onResult,
    required this.kind,
    required this.filters,
  });

  final ValueChanged<LibraryFilterResult?> onResult;
  final LibraryKind kind;
  final LibraryFilters filters;

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: StorizeTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final r = await LibraryFilterSheet.show(
              context,
              targets: const [],
              kind: kind,
              filters: filters,
              today: DateTime(2026, 11, 21),
            );
            onResult(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}
