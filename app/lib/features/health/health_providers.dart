import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_domain/storize_domain.dart';

/// How often the Health screen reads again while it is open (FR-75).
const Duration healthRefreshInterval = Duration(seconds: 15);

/// The read-only Health view model, wired in `appOverrides` to the drift
/// read model. Reading it never calls Instagram.
final healthReadModelProvider = Provider<HealthReadModel>(
  (ref) => throw StateError('healthReadModelProvider is not wired'),
);

/// One read of the Health snapshot. It re-reads every
/// [healthRefreshInterval] while something watches it. A refresh keeps the
/// previous value visible until the new one arrives.
final FutureProvider<HealthSnapshot> healthSnapshotProvider =
    FutureProvider.autoDispose<HealthSnapshot>((ref) {
      final timer = Timer.periodic(
        healthRefreshInterval,
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(timer.cancel);
      return ref.watch(healthReadModelProvider).read();
    });
