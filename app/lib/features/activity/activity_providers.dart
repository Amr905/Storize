import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/activity/activity_model.dart';
import 'package:storize_domain/storize_domain.dart';

/// The events of the last 7 days, newest first. One repo subscription.
final activityEventsProvider = StreamProvider<List<ActivityEvent>>(
  (ref) => ref.watch(activityRepoProvider).watchRecent(),
);

/// All targets, for the `@username` labels. One repo subscription.
final activityTargetsProvider = StreamProvider<List<Target>>(
  (ref) => ref.watch(targetRepoProvider).watchAll(),
);

/// The selected filter chip.
final activityFilterProvider =
    NotifierProvider<ActivityFilterController, ActivityFilter>(
      ActivityFilterController.new,
    );

/// Holds the filter chip.
class ActivityFilterController extends Notifier<ActivityFilter> {
  @override
  ActivityFilter build() => ActivityFilter.all;

  /// Selects [filter].
  // ignore: use_setters_to_change_properties, keeps call sites uniform.
  void select(ActivityFilter filter) => state = filter;
}

/// What S-11 renders. Errors from either stream surface as [AsyncError].
final activityViewProvider = Provider<AsyncValue<ActivityView>>((ref) {
  try {
    final events = ref.watch(activityEventsProvider);
    final targets = ref.watch(activityTargetsProvider);
    final filter = ref.watch(activityFilterProvider);
    final error = events.error ?? targets.error;
    if (error != null && (!events.hasValue || !targets.hasValue)) {
      return AsyncError(
        error,
        events.stackTrace ?? targets.stackTrace ?? StackTrace.current,
      );
    }
    if (!events.hasValue || !targets.hasValue) return const AsyncLoading();
    final now = ref.watch(clockProvider).now();
    return AsyncData(
      buildActivityView(
        events: events.requireValue,
        filter: filter,
        now: now,
        targetsById: {for (final t in targets.requireValue) t.id: t},
      ),
    );
  } on Object catch (e, s) {
    return AsyncError(e, s);
  }
});
