import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// QA T-034 F-1. The app lock is fail-open until `main` overrides
// `appLockWiredProvider` with true (the default is false so other screens'
// tests need no lock fakes). Nothing else enforces the override, so a release
// built from a composition root that forgets it would ship with no lock even
// though the setting says "on".
void main() {
  test(
    'the composition root wires the app lock',
    skip:
        'Enable when the composition root exists (main.dart is a bare '
        'runApp today). Better: make the lock fail-closed by default.',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('appLockWiredProvider'));
      expect(main, contains('pinStoreProvider'));
      expect(main, contains('biometricAuthProvider'));
    },
  );
}
