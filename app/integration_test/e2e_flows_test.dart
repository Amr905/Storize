import 'package:integration_test/integration_test.dart';

import '../test/e2e/e2e_flows.dart';

/// The T-037 flows on a device or emulator:
/// `cd app && flutter test integration_test --flavor dev -d <device>`.
/// They use fakes only: no network, no Instagram, no real WebView.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerE2eFlows();
}
