import 'package:drift/native.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

/// Every repository port under test, wired to one clock.
///
/// The contract suites run against the fake harness and the drift harness and
/// must see the same behaviour.
abstract class RepoHarness {
  TargetRepo get targets;
  ContentRepo get content;
  AccountRepo get accounts;
  ActivityRepo get activity;
  CheckRunRepo get checkRuns;
  GovernorLeaseRepo get leases;
  FakeClock get clock;

  /// Whether this is the drift implementation (for the documented
  /// differences only; contract tests must not branch on it).
  bool get isDrift;

  Future<void> dispose();
}

/// The in-memory fakes from `storize_domain/testing.dart`.
final class FakeHarness implements RepoHarness {
  FakeHarness() {
    targets = FakeTargetRepo();
    content = FakeContentRepo(targets: targets);
    activity = FakeActivityRepo(clock);
    leases = FakeGovernorLeaseRepo(clock);
  }

  @override
  final FakeClock clock = FakeClock();
  @override
  late final FakeTargetRepo targets;
  @override
  late final FakeContentRepo content;
  @override
  final FakeAccountRepo accounts = FakeAccountRepo();
  @override
  late final FakeActivityRepo activity;
  @override
  final FakeCheckRunRepo checkRuns = FakeCheckRunRepo();
  @override
  late final FakeGovernorLeaseRepo leases;

  @override
  bool get isDrift => false;

  @override
  Future<void> dispose() async {}
}

/// The drift repositories over an in-memory database.
final class DriftHarness implements RepoHarness {
  DriftHarness({Duration libraryDebounce = const Duration(milliseconds: 10)})
    : db = StorizeDatabase.forTesting(NativeDatabase.memory()) {
    targets = DriftTargetRepo(db);
    content = DriftContentRepo(db, libraryDebounce: libraryDebounce);
    accounts = DriftAccountRepo(db);
    activity = DriftActivityRepo(db, clock);
    checkRuns = DriftCheckRunRepo(db);
    leases = DriftGovernorLeaseRepo(db, clock);
  }

  final StorizeDatabase db;

  @override
  final FakeClock clock = FakeClock();
  @override
  late final DriftTargetRepo targets;
  @override
  late final DriftContentRepo content;
  @override
  late final DriftAccountRepo accounts;
  @override
  late final DriftActivityRepo activity;
  @override
  late final DriftCheckRunRepo checkRuns;
  @override
  late final DriftGovernorLeaseRepo leases;

  @override
  bool get isDrift => true;

  @override
  Future<void> dispose() => db.close();
}
