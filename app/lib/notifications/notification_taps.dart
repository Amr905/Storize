import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-app locations from notification taps while the app is running.
///
/// `main` overrides it with `NotificationService.taps`; the root widget
/// listens and routes each location through the router, so the lock and
/// onboarding gates still apply. A cold-start tap uses `initialLocation`.
final notificationTapsProvider = StreamProvider<String>(
  (ref) => const Stream<String>.empty(),
);
