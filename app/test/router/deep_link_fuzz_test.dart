// QA fuzz tests for T-025: deep link parsing and the router redirect.
// The prints are the fuzz table quoted in docs/05-reviews/T-025.md.
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/router/deep_link.dart';

import '../helpers/app_harness.dart';

String where(AppHarness h) {
  final c = h.router.routerDelegate.currentConfiguration;
  return c.isEmpty ? 'ERROR_PAGE(${c.error != null})' : h.location;
}

final _known = RegExp(
  r'^/(library|targets|targets/add|targets/\d{1,15}|activity|settings|account|'
  r'story/\d{1,15}|post/\d{1,15}|welcome|login|setup|lock)(\?.*)?$',
);

final List<String> _links = [
  'storize://story/99999999999999999999999',
  'storize://story/999999999999999',
  'storize://story/1000000000000000',
  'storize://story/-5',
  'storize://story/0',
  'storize://story/007',
  'storize://story/٣٤',
  'storize://story/%D9%A3',
  'storize://story/1%2F2',
  'storize://story/1/2',
  'storize://story/../account',
  'storize://story/%2e%2e/account',
  'storize://story/1/',
  'storize://story//1',
  'storize://story/1?x=y',
  'storize://story/1#frag',
  'storize://story/ 1',
  'storize://story/1%0A',
  'storize://story/',
  'storize://story',
  'storize://post/-1',
  'storize://post/1.5',
  'storize://post/1e3',
  'storize://account/extra',
  'storize://account/..',
  'storize://library?target=1&target=2',
  'storize://library?kind=reels',
  'storize://library?kind=',
  'storize://library?kind=posts&kind=stories',
  'storize://library?target=-1',
  'storize://library?target=0',
  'storize://library?target=',
  'storize://library/extra?kind=posts',
  'storize://library?kind=posts%26target%3D1',
  'storize://settings/storage',
  'storize://settings/storage/x',
  'storize://settings/%2e%2e',
  'storize://settings/STORAGE',
  'STORIZE://story/1',
  'Storize://story/1',
  'storize:story/1',
  'storize:/story/1',
  'storize:///story/1',
  'storize://',
  'storize:',
  'storize://lock',
  'storize://welcome',
  'storize://login',
  'storize://targets/add',
  'storize://TARGETS',
  'storize://user:pw@story/1',
  'storize://story:80/1',
  'storize://evil.example/story/1',
  'http://story/1',
  'https://evil.example/',
  'javascript:alert(1)',
  'file:///etc/passwd',
  'intent://story/1#Intent;scheme=storize;end',
];

void main() {
  group('DeepLink.parse fuzz', () {
    for (final raw in _links) {
      test('parse("$raw") never throws and yields a known location', () {
        final uri = Uri.tryParse(raw);
        if (uri == null) return;
        final link = DeepLink.parse(uri);
        if (link == null) {
          expect(uri.scheme, isNot('storize'));
          return;
        }
        expect(link.location, matches(_known), reason: raw);
      });
    }

    test('scheme is case-normalised by Uri', () {
      expect(DeepLink.parse(Uri.parse('STORIZE://story/1')), isA<StoryLink>());
    });

    test('opaque storize:story/1 is treated like storize://story/1', () {
      // Harmless (same destination), documented for the review.
      final link = DeepLink.parse(Uri.parse('storize:story/1'));
      expect(link, isA<StoryLink>());
    });

    test('unicode digits are rejected by parseId', () {
      expect(parseId('٣'), isNull);
      expect(parseId('１'), isNull);
      expect(parseId('1\n'), isNull);
      expect(parseId('1000000000000000'), isNull);
      expect(parseId('999999999999999'), 999999999999999);
      expect(parseId('007'), 7);
    });

    test('duplicate target: Uri.queryParameters keeps the last value', () {
      final parsed = DeepLink.parse(
        Uri.parse('storize://library?target=1&target=2'),
      );
      final link = parsed! as LibraryLink;
      expect(link.targetId, 2); // documents Uri.queryParameters (last wins)
    });
  });

  group('router fuzz', () {
    testWidgets('every link lands on a known route without exceptions', (
      t,
    ) async {
      final h = await pumpApp(t);
      final failures = <String>[];
      for (final raw in _links) {
        try {
          h.router.go(raw);
          await t.pumpAndSettle();
        } on Object catch (e) {
          failures.add('$raw THREW $e');
          continue;
        }
        final ex = t.takeException();
        if (ex != null) failures.add('$raw EXCEPTION $ex');
        final at = where(h);
        // go_router's built-in error page is tolerated (safe, but see review).
        final isError = at.startsWith('ERROR_PAGE');
        if (!isError && !_known.hasMatch(at)) {
          failures.add('$raw -> UNKNOWN $at');
        }
        if (!isError && find.textContaining('TODO(').evaluate().length != 1) {
          failures.add('$raw -> $at: no single placeholder page');
        }
        print('FUZZ $raw -> $at');
      }
      expect(failures, isEmpty);
    });

    testWidgets('non-link garbage paths do not crash', (t) async {
      final h = await pumpApp(t);
      final failures = <String>[];
      for (final raw in [
        '/story/%2F',
        '/story/..%2F..%2Faccount',
        '/story/1/../../account',
        '/../',
        '/%2e%2e/',
        '/targets/%2e%2e',
        '/targets/add/extra',
        '/unknown',
        '//evil.example',
        '/library//',
        '/targets/٣',
        '/targets/99999999999999999999',
      ]) {
        try {
          h.router.go(raw);
          await t.pumpAndSettle();
        } on Object catch (e) {
          failures.add('$raw THREW $e');
          continue;
        }
        final ex = t.takeException();
        print(
          'PATH $raw -> ${where(h)} ex=${ex != null} '
          'todo=${find.textContaining('TODO(').evaluate().length}',
        );
      }
      expect(failures, isEmpty);
    });
  });

  group('from= fuzz', () {
    final froms = <String>[
      '/../',
      '/%2e%2e/%2e%2e/etc',
      'storize://account',
      'storize://story/1',
      '%2F%2Fevil',
      '//evil.example',
      r'/\evil.example',
      '/\t/evil.example',
      'https://evil.example',
      'javascript:alert(1)',
      '/lock',
      '/lock/',
      '/lock?from=/lock',
      '/welcome',
      '/welcome?from=/lock',
      '/login',
      '/setup',
      '/story/1',
      '/account',
      '',
      '/',
      '/unknown',
      '/library?kind=posts',
    ];

    testWidgets('unlocked: /lock?from=X never leaves known routes', (t) async {
      final h = await pumpApp(t);
      final bad = <String>[];
      for (final from in froms) {
        final lockUri = Uri(path: '/lock', queryParameters: {'from': from});
        h.router.go(lockUri.toString());
        await t.pumpAndSettle();
        final ex = t.takeException();
        print('FROM $from -> ${where(h)} ex=${ex != null}');
        if (ex != null) bad.add('$from EXC $ex');
        if (!where(h).startsWith('ERROR_PAGE') && !_known.hasMatch(where(h))) {
          bad.add('$from -> ${where(h)}');
        }
        if (where(h).startsWith('/lock')) bad.add('$from stuck on lock');
      }
      expect(bad, isEmpty);
    });

    testWidgets('onboarded: /welcome?from=X never loops', (t) async {
      final h = await pumpApp(t);
      final bad = <String>[];
      for (final from in froms) {
        h.router.go(
          Uri(path: '/welcome', queryParameters: {'from': from}).toString(),
        );
        await t.pumpAndSettle();
        final ex = t.takeException();
        print('WFROM $from -> ${where(h)} ex=${ex != null}');
        if (ex != null) bad.add('$from EXC $ex');
        if (!where(h).startsWith('ERROR_PAGE') && !_known.hasMatch(where(h))) {
          bad.add('$from -> ${where(h)}');
        }
        if (where(h).startsWith('/welcome')) bad.add('$from stuck');
      }
      expect(bad, isEmpty);
    });
  });

  group('gate flips', () {
    for (final order in ['lock-first', 'onboard-first']) {
      testWidgets('both gates then open in $order', (t) async {
        final lock = gate(appLockedProvider, initial: false);
        final onb = gate(onboardingCompleteProvider, initial: true);
        final h = await pumpApp(
          t,
          overrides: [...lock.overrides, ...onb.overrides],
        );
        await h.go('/targets');
        h.container.read(lock.flag.notifier).set(value: true);
        h.container.read(onb.flag.notifier).set(value: false);
        await t.pumpAndSettle();
        expect(where(h).startsWith('/lock'), isTrue, reason: where(h));
        final first = order == 'lock-first' ? lock : onb;
        if (order == 'lock-first') {
          h.container.read(lock.flag.notifier).set(value: false);
        } else {
          h.container.read(onb.flag.notifier).set(value: true);
        }
        await t.pumpAndSettle();
        print('FLIP $order mid -> ${where(h)}');
        expect(t.takeException(), isNull);
        h.container.read(lock.flag.notifier).set(value: false);
        h.container.read(onb.flag.notifier).set(value: true);
        await t.pumpAndSettle();
        print('FLIP $order end -> ${where(h)} (${first.hashCode != 0})');
        expect(where(h), '/targets');
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('lock then onboarding flips settle on library, no loop', (
      t,
    ) async {
      final lock = gate(appLockedProvider, initial: true);
      final onb = gate(onboardingCompleteProvider, initial: false);
      final h = await pumpApp(
        t,
        overrides: [...lock.overrides, ...onb.overrides],
        initialLocation: 'storize://post/4',
      );
      expect(where(h).startsWith('/lock'), isTrue);
      h.container.read(lock.flag.notifier).set(value: false);
      await t.pumpAndSettle();
      print('LOCKOPEN, onboarding pending -> ${where(h)}');
      expect(where(h).startsWith('/welcome'), isTrue, reason: where(h));
      h.container.read(onb.flag.notifier).set(value: true);
      await t.pumpAndSettle();
      print('BOTH OPEN -> ${where(h)}');
      expect(where(h), '/post/4');
    });
  });

  group('tabs', () {
    testWidgets('system back from non-Library tab roots', (t) async {
      final h = await pumpApp(t);
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Activity'),
        ),
      );
      await t.pumpAndSettle();
      final handled = await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      print('BACK from /activity: handled=$handled -> ${where(h)}');
    });
  });
}
