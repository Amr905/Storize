import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/targets/targets_providers.dart';

import '../features/targets/targets_rig.dart';

void main() {
  test('Library Check now checks all targets (no id)', () async {
    final check = FakeCheckNow();
    final c = ProviderContainer(
      overrides: [checkNowActionProvider.overrideWithValue(check)],
    );
    addTearDown(c.dispose);
    await c.read(checkNowControllerProvider.notifier).run();
    expect(check.targetIds, [null]);
  });

  test('Targets Check now checks all; S-09 passes its id', () async {
    final check = FakeCheckNow();
    final c = ProviderContainer(
      overrides: [checkNowActionProvider.overrideWithValue(check)],
    );
    addTearDown(c.dispose);
    final n = c.read(targetCheckRunningProvider.notifier);
    await n.checkAll();
    await n.checkAll(targetId: 7);
    expect(check.targetIds, [null, 7]);
  });

  test('staging clear is called only from the foreground main()', () {
    final lib = Directory('lib');
    final callers = [
      for (final f in lib.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('clearStagingSession()') &&
            !f.path.endsWith('core/composition.dart'))
          f.path,
    ];
    expect(callers, ['lib/main.dart']);
    final bg = File('lib/background/background_dispatcher.dart')
        .readAsStringSync();
    expect(bg, isNot(contains('clearStagingSession')));
  });
}
