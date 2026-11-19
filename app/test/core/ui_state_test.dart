import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/ui_state.dart';
import 'package:storize_app/core/ui_state_view.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

import '../ui/golden_helpers.dart';

Widget host(UiState<List<int>> state, {Brightness b = Brightness.light}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: b == Brightness.light ? StorizeTheme.light() : StorizeTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: UiStateView<List<int>>(
          state: state,
          builder: (_, v) => Center(child: Text('items ${v.length}')),
        ),
      ),
    );

void main() {
  setUpAll(loadTestFonts);

  group('AsyncValue to UiState', () {
    test('loading', () {
      expect(const AsyncLoading<int>().toUiState(), const UiLoading<int>());
    });

    test('data becomes content', () {
      expect(const AsyncData(3).toUiState(), const UiContent(3));
    });

    test('empty by predicate, with reason', () {
      const v = AsyncData<List<int>>([]);
      expect(
        v.toUiState(isEmpty: (l) => l.isEmpty),
        const UiEmpty<List<int>>(EmptyReason.noData),
      );
      expect(
        v.toUiState(
          isEmpty: (l) => l.isEmpty,
          emptyReason: EmptyReason.filteredOut,
        ),
        const UiEmpty<List<int>>(EmptyReason.filteredOut),
      );
    });

    test('error maps kind and carries retry', () {
      var called = 0;
      final s = AsyncError<int>(
        StateError('x'),
        StackTrace.empty,
      ).toUiState(errorKind: (_) => UiErrorKind.network, retry: () => called++);
      expect(s, isA<UiError<int>>());
      final e = s as UiError<int>;
      expect(e.kind, UiErrorKind.network);
      e.retry!();
      expect(called, 1);
    });

    test('error defaults to unknown', () {
      const error = AsyncError<int>(1, StackTrace.empty);
      final s = error.toUiState();
      expect((s as UiError<int>).kind, UiErrorKind.unknown);
    });

    test('a refresh or failed refresh keeps the old value', () async {
      var calls = 0;
      final pending = Completer<int>();
      final provider = FutureProvider<int>(
        (ref) => calls++ == 0 ? Future.value(1) : pending.future,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(provider, (_, _) {});
      await container.read(provider.future);

      container.invalidate(provider);
      final refreshing = container.read(provider);
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.toUiState(), const UiContent(1));

      pending.completeError('boom');
      await Future<void>.delayed(Duration.zero);
      final failed = container.read(provider);
      expect(failed.hasError, isTrue);
      expect(failed.toUiState(), const UiContent(1));
    });
  });

  group('UiStateView', () {
    testWidgets('loading shows a skeleton', (t) async {
      await t.pumpWidget(host(const UiLoading()));
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('grid loading style', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UiStateView<int>(
            state: UiLoading(),
            loadingStyle: UiLoadingStyle.grid,
            builder: _unused,
          ),
        ),
      );
      expect(find.byType(SkeletonGrid), findsOneWidget);
    });

    testWidgets('content uses the builder', (t) async {
      await t.pumpWidget(host(const UiContent([1, 2])));
      expect(find.text('items 2'), findsOneWidget);
    });

    testWidgets('empty shows the empty state per reason', (t) async {
      await t.pumpWidget(host(const UiEmpty(EmptyReason.noData)));
      expect(find.text('Nothing here yet'), findsOneWidget);
      await t.pumpWidget(host(const UiEmpty(EmptyReason.filteredOut)));
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('empty builder overrides the default', (t) async {
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UiStateView<int>(
            state: const UiEmpty(EmptyReason.noData),
            builder: _unused,
            emptyBuilder: (_, r) => Text('custom ${r.name}'),
          ),
        ),
      );
      expect(find.text('custom noData'), findsOneWidget);
    });

    testWidgets('error shows Retry that calls retry', (t) async {
      var retried = 0;
      await t.pumpWidget(
        host(UiError(UiErrorKind.network, retry: () => retried++)),
      );
      expect(find.text('No internet connection'), findsOneWidget);
      await t.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('error without retry has no button', (t) async {
      await t.pumpWidget(host(const UiError(UiErrorKind.unknown)));
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    for (final kind in UiErrorKind.values) {
      testWidgets('error kind ${kind.name} renders', (t) async {
        await t.pumpWidget(host(UiError(kind, retry: () {})));
        expect(find.byType(EmptyState), findsOneWidget);
      });
    }
  });

  group('goldens', () {
    final states = <String, UiState<List<int>>>{
      'loading': const UiLoading(),
      'empty': const UiEmpty(EmptyReason.noData),
      'empty_filtered': const UiEmpty(EmptyReason.filteredOut),
      'error': UiError(UiErrorKind.network, retry: () {}),
      'content': const UiContent([1, 2, 3]),
    };
    for (final MapEntry(:key, :value) in states.entries) {
      for (final b in Brightness.values) {
        testWidgets('ui_state_${key}_${b.name}', (t) async {
          t.view
            ..devicePixelRatio = 1
            ..physicalSize = const Size(400, 520);
          addTearDown(t.view.reset);
          await t.pumpWidget(host(value, b: b));
          await t.pump();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/ui_state_${key}_${b.name}.png'),
          );
        });
      }
    }
  });
}

Widget _unused(BuildContext context, int value) => const SizedBox();
