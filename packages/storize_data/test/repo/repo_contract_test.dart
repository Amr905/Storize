// One contract suite per port, run against the in-memory fake and the drift
// implementation. Both must show the same observable behaviour. Where they
// legitimately differ, see `repo_differences_test.dart`.
import 'package:flutter_test/flutter_test.dart';

import 'contract/account_activity_contract.dart';
import 'contract/check_run_lease_contract.dart';
import 'contract/content_repo_contract.dart';
import 'contract/target_repo_contract.dart';
import 'support/harness.dart';

void main() {
  final implementations = <String, RepoHarness Function()>{
    'fake': FakeHarness.new,
    'drift': DriftHarness.new,
  };
  for (final MapEntry(key: name, value: create) in implementations.entries) {
    group('$name:', () {
      group('TargetRepo', () => runTargetRepoContract(create));
      group('ContentRepo', () => runContentRepoContract(create));
      group('AccountRepo', () => runAccountRepoContract(create));
      group('ActivityRepo', () => runActivityRepoContract(create));
      group('CheckRunRepo', () => runCheckRunRepoContract(create));
      group('GovernorLeaseRepo', () => runGovernorLeaseRepoContract(create));
    });
  }
}
