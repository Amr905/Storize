import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/features/onboarding/inapp_login_web_view.dart';
import 'package:storize_app/features/onboarding/login_lease.dart';
import 'package:storize_app/features/onboarding/login_web_view.dart';
import 'package:storize_app/features/onboarding/setup_ops.dart';

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
