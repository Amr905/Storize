// T-013 follow-up, T-044: the GraphQL-then-REST fallback is the default; REST
// alone only when a probe report says restProven.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_instagram/probe/probe.dart';

import '../direct/support.dart';

ProbeReport _report({required bool proven}) => ProbeReport(
  entries: [
    for (final id in ProbeEntry.expectedKeys.keys)
      ProbeEntry(
        id: id,
        label: 'x',
        outcome: proven ? 'ok' : 'http_error',
        status: proven ? 200 : 404,
        topLevelKeys: proven ? ProbeEntry.expectedKeys[id]! : const [],
      ),
  ],
);

IgTransport _select({
  TransportPreference? preference,
  ProbeReport? probe,
}) => selectTransport(
  docIds: FakeDocIds(),
  tokens: FakeTokens(),
  preference: preference ?? TransportPreference.graphql,
  probe: probe,
);

void main() {
  test('the fixture reports mean what the names say', () {
    expect(_report(proven: true).restProven, isTrue);
    expect(_report(proven: false).restProven, isFalse);
  });

  test('the default is the GraphQL-then-REST fallback', () {
    expect(_select().name, 'fallback');
    expect(
      selectTransport(docIds: FakeDocIds(), tokens: FakeTokens()).name,
      'fallback',
    );
  });

  test(
    'the fallback stays even with a proven probe unless REST is asked for',
    () {
      expect(_select(probe: _report(proven: true)).name, 'fallback');
    },
  );

  test('restWhenProven + proven probe: REST', () {
    expect(
      _select(
        preference: TransportPreference.restWhenProven,
        probe: _report(proven: true),
      ).name,
      'rest',
    );
  });

  test('restWhenProven without a probe, with a failed one or an empty one: '
      'the fallback', () {
    for (final probe in [
      null,
      _report(proven: false),
      const ProbeReport(entries: []),
    ]) {
      expect(
        _select(
          preference: TransportPreference.restWhenProven,
          probe: probe,
        ).name,
        'fallback',
      );
    }
  });
}
