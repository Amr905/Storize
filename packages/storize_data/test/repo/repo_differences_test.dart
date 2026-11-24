// The places where the fakes and the drift repositories legitimately differ.
// Each difference is asserted for BOTH implementations so a change on either
// side is noticed. The shared behaviour lives in `repo_contract_test.dart`.
import 'dart:convert';

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'contract/account_activity_contract.dart';
import 'support/builders.dart';
import 'support/harness.dart';

void main() {
  group('fake', () => _differences(FakeHarness.new, isDrift: false));
  group('drift', () => _differences(DriftHarness.new, isDrift: true));
}

void _differences(RepoHarness Function() create, {required bool isDrift}) {
  late RepoHarness h;
  setUp(() => h = create());
  tearDown(() => h.dispose());

  // 1. Foreign keys. drift enforces them; the fakes do not check that a
  // referenced row exists.
  test('foreign keys: unknown references', () async {
    Future<void> content() =>
        h.content.insertIfNew(aContent(404), [aMedia()]).then((_) {});
    Future<void> activity() =>
        h.activity.add(anEvent(at: h.clock.now(), targetId: 404)).then((_) {});
    Future<void> targetAccount() =>
        h.targets.insert(aTarget(loginAccountId: 404)).then((_) {});
    for (final call in [content, activity, targetAccount]) {
      if (isDrift) {
        // FK violation (787): a SqliteException, not a duplicate.
        await expectLater(
          call(),
          throwsA(
            allOf(
              isA<SqliteException>(),
              isNot(isA<DuplicateEntityException>()),
            ),
          ),
        );
      } else {
        await call();
      }
    }
  });

  // 2. Deleting a target keeps its activity events in drift (target_id set to
  // NULL); the fake keeps the dangling target id.
  test('deleting a target: activity events', () async {
    final target = await h.targets.insert(aTarget());
    await h.activity.add(anEvent(at: h.clock.now(), targetId: target.id));
    await h.targets.delete(target.id);
    final event = await h.activity.watchRecent().first;
    expect(event, hasLength(1));
    expect(event.single.targetId, isDrift ? isNull : target.id);
  });

  // 4. Time precision: drift stores epoch milliseconds in UTC. The fake keeps
  // the DateTime object it was given (microseconds, local zone).
  test('dates: sub-millisecond precision and non-UTC input', () async {
    final precise = DateTime.utc(2026, 3, 10, 12, 0, 0, 123, 456);
    final local = DateTime.utc(2026, 3, 10, 12).toLocal();
    final stored = await h.accounts.upsert(
      anAccount(connectedAt: precise, lastSuccessAt: local),
    );
    final read = (await h.accounts.getActive())!;
    expect(read.id, stored.id);
    if (isDrift) {
      expect(read.connectedAt, DateTime.utc(2026, 3, 10, 12, 0, 0, 123));
      expect(read.lastSuccessAt!.isUtc, isTrue);
    } else {
      expect(read.connectedAt, precise);
    }
    // Same instant in both.
    expect(read.lastSuccessAt!.isAtSameMomentAs(local), isTrue);
  });

  // 5. JSON columns: drift stores extras/payload as JSON text, so values that
  // JSON cannot encode are rejected. The fake keeps any object.
  test('payload values that JSON cannot encode', () async {
    final event = anEvent(at: h.clock.now(), payload: {'when': Object()});
    if (isDrift) {
      await expectLater(
        h.activity.add(event),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    } else {
      await h.activity.add(event);
    }
  });

  // 6. Check-run ties on started_at: the fake keeps the first-inserted run, the
  // DAO orders by (started_at DESC, id DESC) and returns the last-inserted.
  test('lastFinished with equal startedAt', () async {
    final first = await h.checkRuns.start(
      scope: CheckScope.stories,
      trigger: CheckTrigger.periodic,
      startedAt: at(1),
    );
    final second = await h.checkRuns.start(
      scope: CheckScope.stories,
      trigger: CheckTrigger.periodic,
      startedAt: at(1),
    );
    for (final r in [first, second]) {
      await h.checkRuns.finish(
        r.id,
        finishedAt: at(2),
        result: CheckResult.ok,
      );
    }
    expect(
      (await h.checkRuns.lastFinished(CheckScope.stories))!.id,
      isDrift ? second.id : first.id,
    );
  });

  // 7. Library stream: the fake emits once per change; drift's repo coalesces
  // bursts (debounce) after the first value. Only the final state is promised.
  test('library stream emission count for a burst', () async {
    final target = await h.targets.insert(aTarget());
    final w = Watch(h.content.watchLibrary(ContentFilter()));
    addTearDown(w.cancel);
    await w.until((l) => l.isEmpty);
    w.mark();
    for (var i = 0; i < 6; i++) {
      await h.content.insertIfNew(aContent(target.id, remoteId: 'r$i'), [
        aMedia(),
      ]);
    }
    await w.until((l) => l.length == 6);
    final emissionsAfterInitial = w.values.length - 1;
    if (isDrift) {
      expect(emissionsAfterInitial, lessThan(6));
    } else {
      expect(emissionsAfterInitial, 6);
    }
  });
}
