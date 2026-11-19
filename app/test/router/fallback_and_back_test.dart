import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/gates.dart';

import '../helpers/app_harness.dart';

void main() {
  group('unknown locations go to the Library', () {
    for (final bad in [
      '/unknown',
      '/library//',
      '/targets/add/extra',
      'http://story/1',
      'https://evil.example/',
      '/%2e%2e/%2e%2e/etc',
    ]) {
      testWidgets('"$bad"', (t) async {
        final h = await pumpApp(t, initialLocation: '/targets');
        await h.go(bad);
        expect(h.location, '/library');
        expect(find.text('TODO(T-027)'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('as the launch location', (t) async {
      final h = await pumpApp(t, initialLocation: '/unknown');
      expect(h.location, '/library');
    });

    for (final from in ['/unknown', '/%2e%2e/%2e%2e/etc']) {
      testWidgets('unsafe from "$from" after a gate', (t) async {
        final g = gate(appLockedProvider, initial: true);
        final h = await pumpApp(
          t,
          initialLocation: Uri(
            path: '/lock',
            queryParameters: {'from': from},
          ).toString(),
          overrides: g.overrides,
        );
        h.container.read(g.flag.notifier).set(value: false);
        await t.pumpAndSettle();
        expect(h.location, '/library');
        expect(t.takeException(), isNull);
      });
    }
  });

  group('Android back', () {
    Future<void> back(WidgetTester t) async {
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
    }

    for (final tab in ['/targets', '/activity', '/settings']) {
      testWidgets('from the root of $tab goes to Library', (t) async {
        final h = await pumpApp(t);
        await h.go(tab);
        await back(t);
        expect(h.location, '/library');
        expect(find.text('TODO(T-027)'), findsOneWidget);
      });
    }

    testWidgets('from a pushed detail pops it first, then goes to Library', (
      t,
    ) async {
      final h = await pumpApp(t);
      await h.go('/targets');
      await h.push('/targets/4');
      await back(t);
      expect(h.location, '/targets');
      await back(t);
      expect(h.location, '/library');
    });

    testWidgets('from the Library root the app exits', (t) async {
      await pumpApp(t);
      var exited = false;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exited = true;
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(exited, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
