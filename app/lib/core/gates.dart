/// Routing gates. These are hooks only: the router consults them and sends
/// the user to S-01 (onboarding) or S-14 (lock) while they say so.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether first-run onboarding (S-01 to S-03) is finished.
///
/// Defaults to true. T-026 provides the real value (false on first run).
final onboardingCompleteProvider = Provider<bool>((ref) => true);

/// Whether the app is locked and must show S-14.
///
/// Defaults to false. T-034 provides the real value.
final appLockedProvider = Provider<bool>((ref) => false);
