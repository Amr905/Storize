// QA tests for T-045 (persisted page discovery, REST gating, diagnostics).
// Synthetic ZZFAKE_ values only.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _u = 'ZZFAKE_user_a';

/// A store whose every call yields for [lag] turns, so two instances
/// interleave like two isolates sharing one secure-storage entry.
final class _SlowStore implements DiscoveryStore {
  _SlowStore(this.lag);
  final int lag;
  final InMemoryDiscoveryStore inner = InMemoryDiscoveryStore();

  Future<void> _yield() async {
    for (var i = 0; i < lag; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<DiscoverySnapshot?> load(int id) async {
    await _yield();
    return inner.load(id);
  }

  @override
  Future<void> save(int id, DiscoverySnapshot s) async {
    await _yield();
    return inner.save(id, s);
  }

  @override
  Future<void> clear(int id) async {
    await _yield();
    return inner.clear(id);
  }
}

PageDiscovery _d(DiscoveryStore s, FakeClock c, [int id = 1]) =>
    PageDiscovery(clock: c, store: s, accountId: id);

void _rec(PageDiscovery d, GraphqlQuery q, {bool tokens = true}) => d.record(
  friendlyName: q.friendlyName,
  docId: 'ZZFAKE_doc_${q.name}',
  tokens: tokens ? {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd} : const {},
);

void main() {
  group('concurrency (two isolates, one store)', () {
    test(
      'interleaved writers keep valid data; both doc_ids survive',

      () async {
        final clock = FakeClock();
        final store = _SlowStore(3);
        final a = _d(store, clock);
        final b = _d(store, clock);
        _rec(a, GraphqlQuery.stories);
        _rec(b, GraphqlQuery.values.last, tokens: false);
        await Future.wait([a.flush(), b.flush()]);
        final snap = (await store.inner.load(1))!;
        // The store never holds corrupt JSON.
        expect(DiscoverySnapshot.fromJson(snap.toJson()), isNotNull);
        expect(
          snap.docIds.keys,
          containsAll([
            GraphqlQuery.stories.name,
            GraphqlQuery.values.last.name,
          ]),
          reason: 'read-modify-write is not atomic: one writer lost the other',
        );
      },
    );

    test('a newer value is not overwritten by an older reload', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final a = _d(store, clock);
      final b = _d(store, clock);
      _rec(a, GraphqlQuery.stories);
      await a.flush();
      clock.advance(const Duration(hours: 1));
      b.record(
        friendlyName: GraphqlQuery.stories.friendlyName,
        docId: 'ZZFAKE_doc_newer',
        tokens: const {},
      );
      await b.flush();
      expect(
        await a.docIdFor(GraphqlQuery.stories),
        'ZZFAKE_doc_stories',
        reason: 'A keeps its memory until it expires',
      );
      final c = _d(store, clock);
      expect(await c.docIdFor(GraphqlQuery.stories), 'ZZFAKE_doc_newer');
    });
  });

  group('logout', () {
    test(
      'clear() in one isolate: a stale instance does not resurrect tokens',

      () async {
        final clock = FakeClock();
        final store = InMemoryDiscoveryStore();
        final fg = _d(store, clock);
        final bg = _d(store, clock);
        _rec(fg, GraphqlQuery.stories);
        await fg.flush();
        expect(await bg.tokens(), isNotNull); // bg adopts into memory
        // Logout: the session store clears the store behind both instances.
        await store.clear(1);
        // bg later records one doc_id (no tokens) and persists.
        _rec(bg, GraphqlQuery.values.last, tokens: false);
        await bg.flush();
        final after = await store.load(1);
        expect(
          after?.tokens,
          isNull,
          reason: 'stale in-memory tokens were written back after logout',
        );
      },
    );
  });

  group('corrupt and foreign JSON', () {
    for (final raw in [
      '',
      'null',
      '[]',
      '{"v":2}',
      '{"v":1,"docIds":{"stories":{"id":5,"at":"x"}},"tokens":{"a":1}}',
      '{"v":1,"tokens":{"fb_dtsg":"ZZFAKE"},"tokensAt":99999999999999999999}',
      '{"v":1,"docIds":{"s":{"id":"ZZFAKE","at":-5}}}',
      '{"v":1,"docIds":[1,2],"tokens":"ZZFAKE"}',
    ]) {
      test('reads without throwing: $raw', () {
        final snap = DiscoverySnapshot.fromJson(raw);
        if (snap != null) {
          expect(snap.tokens, isNull);
          expect(snap.docIds, isEmpty);
        }
      });
    }

    test('tokens without a time are dropped', () {
      final snap = DiscoverySnapshot.fromJson(
        jsonEncode({
          'v': 1,
          'tokens': {'fb_dtsg': 'ZZFAKE'},
        }),
      )!;
      expect(snap.tokens, isNull);
    });
  });

  group('TTL edges', () {
    test(
      'doc_id gone just past 6 h, tokens just past 12 h, from a store',
      () async {
        final clock = FakeClock();
        final store = InMemoryDiscoveryStore();
        final w = _d(store, clock);
        _rec(w, GraphqlQuery.stories);
        await w.flush();
        final r = _d(store, clock);
        clock.advance(const Duration(hours: 6, seconds: 1));
        expect(await r.docIdFor(GraphqlQuery.stories), isNull);
        expect(await r.tokens(), isNotNull);
        clock.advance(const Duration(hours: 6));
        expect(await r.tokens(), isNull);
      },
    );
  });

  group('account isolation', () {
    test('B never sees A, and B writes leave A intact', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final a = _d(store, clock);
      final b = _d(store, clock, 2);
      _rec(a, GraphqlQuery.stories);
      await a.flush();
      expect(await b.docIdFor(GraphqlQuery.stories), isNull);
      expect(await b.tokens(), isNull);
      b.record(
        friendlyName: GraphqlQuery.stories.friendlyName,
        docId: 'ZZFAKE_b',
        tokens: const {'lsd': 'ZZFAKE_b_lsd'},
      );
      await b.flush();
      expect(
        (await store.load(1))!.docIds['stories']!.docId,
        'ZZFAKE_doc_stories',
      );
      b.clear();
      await b.flush();
      expect(await store.load(1), isNotNull);
    });
  });

  group('traffic', () {
    Rig rig(PageDiscovery d, {Responder? responder}) => Rig(
      transport: FallbackTransport(docIds: d, tokens: d),
      responder: responder ?? (_) => throw StateError('no request expected'),
    );

    test(
      'no discovery, no proof: every non-bootstrap op sends nothing',
      () async {
        final d = PageDiscovery(clock: FakeClock());
        final r = rig(d);
        final results = <Result<Object?>>[
          await r.run(r.extractor.fetchStories([_u])),
          await r.run(r.extractor.fetchNewPosts(_u, DateTime.utc(2026))),
          await r.run(r.extractor.fetchPostPage(_u)),
          await r.run(r.extractor.fetchHighlights(_u)),
          await r.run(r.extractor.latestStoryTime(_u)),
          await r.run(r.extractor.latestPostTime(_u)),
        ];
        expect(r.http.requests, isEmpty);
        for (final res in results) {
          expect(res.failureOrNull, isA<SchemaChanged>());
        }
      },
    );

    test(
      'a stale doc_id: SchemaChanged drops it, the next run sends nothing',
      () async {
        final clock = FakeClock();
        final store = InMemoryDiscoveryStore();
        final d = _d(store, clock);
        for (final q in GraphqlQuery.values) {
          _rec(d, q);
        }
        await d.flush();
        final r = rig(
          d,
          responder: (_) => jsonReply({
            'data': {'unexpected': 1},
          }),
        );
        final first = await r.run(r.extractor.fetchStories([_u]));
        expect(first.failureOrNull, isA<SchemaChanged>());
        final sent = r.http.requests.length;
        expect(sent, 1, reason: 'one GraphQL try, no REST');
        final again = await r.run(r.extractor.fetchStories([_u]));
        expect(again.failureOrNull, isA<SchemaChanged>());
        expect(
          r.http.requests.length,
          sent,
          reason: 'dropped doc_id: no resend',
        );
        final snap = await store.load(1);
        expect(snap?.docIds[GraphqlQuery.stories.name], isNull);
      },
    );

    test('logs never carry tokens or doc_ids, success or failure', () async {
      final clock = FakeClock();
      final d = _d(InMemoryDiscoveryStore(), clock);
      for (final q in GraphqlQuery.values) {
        _rec(d, q);
      }
      await d.flush();
      for (final reply in [
        jsonReply({
          'message': 'ZZFAKE_dtsg_value please wait',
          'x': 1,
        }, status: 429),
        jsonReply({'ZZFAKE_lsd_value': 1, 'data': 5}),
        jsonReply({'error_type': 'ZZFAKE_doc_stories'}, status: 500),
      ]) {
        final r = rig(d, responder: (_) => reply);
        await r.run(r.extractor.fetchStories([_u]));
        final logs = r.allLogs;
        for (final secret in [
          fakeDtsg,
          fakeLsd,
          'ZZFAKE_doc_',
          fakeSessionId,
        ]) {
          expect(logs, isNot(contains(secret)), reason: logs);
        }
      }
    });

    test('rate-limit log line: op, transport, status, hint', () async {
      final d = PageDiscovery(clock: FakeClock());
      for (final q in GraphqlQuery.values) {
        _rec(d, q);
      }
      final r = rig(
        d,
        responder: (_) =>
            jsonReply({'message': 'Please wait a few minutes'}, status: 429),
      );
      await r.run(r.extractor.fetchStories([_u]));
      final line = r.log.entries
          .map((e) => e.message)
          .firstWhere((m) => m.contains('rate_limited'));
      expect(line, contains('op=fetchStories'));
      expect(line, contains('via=graphql'));
      expect(line, contains('status=429'));
      expect(line, contains('hint=please_wait'));
    });
  });
}
