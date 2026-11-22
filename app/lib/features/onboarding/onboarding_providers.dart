import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/onboarding/inapp_login_web_view.dart';
import 'package:storize_app/features/onboarding/login_lease.dart';
import 'package:storize_app/features/onboarding/login_web_view.dart';
import 'package:storize_app/features/onboarding/setup_ops.dart';
import 'package:storize_domain/storize_domain.dart';

/// The WebView lease S-02 holds (key -1). Wired by the composition root.
final loginLeaseProvider = Provider<LoginLease>(
  (ref) => throw UnimplementedError(
    'loginLeaseProvider is not wired. Override it in main() or in the test.',
  ),
);

/// Builds the login WebView. Tests override it with a fake.
final loginWebViewBuilderProvider = Provider<LoginWebViewBuilder>(
  (ref) => buildInAppLoginWebView,
);

/// Device operations for S-03. Wired by the composition root.
final setupOpsProvider = Provider<SetupOps>(
  (ref) => throw UnimplementedError(
    'setupOpsProvider is not wired. Override it in main() or in the test.',
  ),
);

/// The platform S-02 verifies a new session with. It reads the staging
/// session (`LoginAccount.unsavedId`), not the active account's. Wired by the
/// composition root.
/// Waits between login lease attempts before S-02 shows "Login isn't
/// available right now". The first lease call is also the app's first
/// database call after install, and on a phone (debug builds above all) the
/// database can take longer to open than one attempt waits. Tests override
/// this with an empty list.
final loginAcquireBackoffProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
  ],
);

final loginPlatformProvider = Provider<ContentPlatform>(
  (ref) => throw UnimplementedError(
    'loginPlatformProvider is not wired. Override it in main() or in the test.',
  ),
);

/// The stored `onboardingDone` setting. The composition root feeds the
/// `onboardingCompleteProvider` gate from it.
final onboardingDoneProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsRepoProvider)
      .watch()
      .map((s) => s.onboardingDone)
      .distinct(),
);

/// Set when the user leaves S-03 with Done or Skip in this run. The gate
/// opens on it at once, before the stored `onboardingDone` stream catches up
/// (QA T-026 finding 1: the flag is written at S-03, not at login).
final setupFinishedProvider = NotifierProvider<SetupFinished, bool>(
  SetupFinished.new,
);

/// Holds [setupFinishedProvider].
class SetupFinished extends Notifier<bool> {
  @override
  bool build() => false;

  /// Marks onboarding finished for this run.
  void mark() => state = true;
}
