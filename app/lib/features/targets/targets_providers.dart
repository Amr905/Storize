import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// How long a rate-limit event keeps the S-07 warning bar visible.
const Duration targetsRateLimitWindow = Duration(hours: 1);

/// All tracked accounts, ordered by username. One repo subscription.
final targetsProvider = StreamProvider<List<Target>>(
  (ref) => ref.watch(targetRepoProvider).watchAll(),
);

/// The logged-in account's username, read once (for the S-08 messages). It
/// does not subscribe to `watchActive`, which the session banner already does.
final FutureProvider<String?> targetsLoginNameProvider =
    FutureProvider.autoDispose<String?>(
      (ref) async =>
          (await ref.watch(accountRepoProvider).getActive())?.username,
    );

final _activeAccountProvider = StreamProvider<LoginAccount?>(
  (ref) => ref.watch(accountRepoProvider).watchActive(),
);

/// True when the login session is usable (BR-7): there is an account and its
/// status is `active`. Check now and Add are disabled otherwise, including
/// when logged out or while the account is still loading.
final targetsSessionActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(_activeAccountProvider).value?.status == AccountStatus.active,
);

final _rateLimitEventsProvider = StreamProvider<List<ActivityEvent>>(
  (ref) => ref
      .watch(activityRepoProvider)
      .watchRecent(types: {ActivityType.rateLimited}),
);

/// True when Storize slowed checks down recently (EC-15). Drives the S-07
/// warning bar.
final targetsRateLimitedProvider = Provider<bool>((ref) {
  final events = ref.watch(_rateLimitEventsProvider).value;
  if (events == null || events.isEmpty) return false;
  try {
    final now = ref.watch(clockProvider).now();
    final newest = events
        .map((e) => e.at)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return now.difference(newest) < targetsRateLimitWindow;
  } on Object {
    return false;
  }
});

/// True while a "Check now" run is in progress. Rows show "Checking".
final targetCheckRunningProvider =
    NotifierProvider<TargetCheckController, bool>(
      TargetCheckController.new,
    );

/// Runs "Check now" through [checkNowActionProvider] and tracks its state.
class TargetCheckController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Checks all active targets. Returns null when a run is already going.
  Future<CheckNowResult?> checkAll() async {
    if (state) return null;
    state = true;
    try {
      return await ref.read(checkNowActionProvider).call();
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

/// Changes a target's status (pause and resume, FR-14).
final targetActionsProvider = Provider<TargetActions>(
  (ref) => TargetActions(ref.watch(targetRepoProvider)),
);

/// Pause and resume for one target.
class TargetActions {
  /// Creates the actions over [_targets].
  const TargetActions(this._targets);

  final TargetRepo _targets;

  /// Pauses the target, or resumes it when [paused] is false. Throws when the
  /// repository fails; the caller reports it.
  Future<void> setPaused(Target target, {required bool paused}) async {
    final current = await _targets.getById(target.id);
    if (current == null) return;
    await _targets.update(
      current.copyWith(
        status: paused ? TargetStatus.paused : TargetStatus.active,
      ),
    );
  }
}

/// The add use case (FR-10 to FR-16, BR-1, BR-2).
final addTargetUseCaseProvider = Provider<AddTarget>(
  (ref) => AddTarget(
    platform: ref.watch(contentPlatformProvider),
    targets: ref.watch(targetRepoProvider),
    scheduler: ref.watch(schedulerProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// The tracks a user can toggle on S-08.
enum TrackKind { stories, posts, reels }

/// The S-08 form state. Text is kept here too, so validation is pure.
@immutable
class AddTargetForm {
  /// Creates the state. Everything is on by default (FR-65, FR-67).
  const AddTargetForm({
    this.username = '',
    this.note = '',
    this.category,
    this.tracks = const {
      TrackKind.stories,
      TrackKind.posts,
      TrackKind.reels,
    },
    this.submitted = false,
    this.trackRejected = false,
    this.verifying = false,
    this.failure,
  });

  /// The text in the username field.
  final String username;

  /// The text in the note field.
  final String note;

  /// The chosen category, or null (BR-1).
  final TargetCategory? category;

  /// The tracks that are on. Never empty.
  final Set<TrackKind> tracks;

  /// True after the first submit attempt; enables the "required" messages.
  final bool submitted;

  /// True after the user tried to turn off the last track (F-1).
  final bool trackRejected;

  /// True while the add use case runs.
  final bool verifying;

  /// The last failed result to show inline or as a snackbar, or null.
  final AddTargetResult? failure;

  /// The username normalized the way [AddTarget] does, or null if invalid.
  String? get normalized => AddTarget.normalizeUsername(username);

  /// Whether the note is too long to be stored (FR-16).
  bool get noteTooLong => note.trim().length > Target.maxNoteLength;

  /// Whether every local rule passes.
  bool get canSubmit =>
      normalized != null &&
      category != null &&
      tracks.isNotEmpty &&
      !noteTooLong;

  /// Whether [kind] is on.
  bool isOn(TrackKind kind) => tracks.contains(kind);

  /// Returns a copy with the given fields replaced. [clearFailure] drops
  /// [failure].
  AddTargetForm copyWith({
    String? username,
    String? note,
    TargetCategory? category,
    Set<TrackKind>? tracks,
    bool? submitted,
    bool? trackRejected,
    bool? verifying,
    AddTargetResult? failure,
    bool clearFailure = false,
  }) => AddTargetForm(
    username: username ?? this.username,
    note: note ?? this.note,
    category: category ?? this.category,
    tracks: tracks ?? this.tracks,
    submitted: submitted ?? this.submitted,
    trackRejected: trackRejected ?? this.trackRejected,
    verifying: verifying ?? this.verifying,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// The S-08 form. Auto-disposed, so every visit starts empty.
final NotifierProvider<AddTargetFormController, AddTargetForm>
addTargetFormProvider =
    NotifierProvider.autoDispose<AddTargetFormController, AddTargetForm>(
      AddTargetFormController.new,
    );

/// Holds the S-08 form and runs the add.
class AddTargetFormController extends Notifier<AddTargetForm> {
  @override
  AddTargetForm build() => const AddTargetForm();

  /// Updates the username text.
  void setUsername(String value) =>
      state = state.copyWith(username: value, clearFailure: true);

  /// Updates the note text.
  void setNote(String value) => state = state.copyWith(note: value);

  /// Chooses a category.
  void selectCategory(TargetCategory category) =>
      state = state.copyWith(category: category, clearFailure: true);

  /// Turns [kind] on or off. The last track cannot be turned off (F-1).
  void toggleTrack(TrackKind kind) {
    final next = {...state.tracks};
    if (!next.remove(kind)) next.add(kind);
    if (next.isEmpty) {
      state = state.copyWith(trackRejected: true);
      return;
    }
    state = state.copyWith(tracks: next, trackRejected: false);
  }

  /// Validates and adds the account. Returns the use case result, or null
  /// when local validation stopped the submit.
  Future<AddTargetResult?> submit() async {
    if (state.verifying) return null;
    state = state.copyWith(submitted: true, clearFailure: true);
    if (!state.canSubmit) return null;
    state = state.copyWith(verifying: true);
    final result = await ref
        .read(addTargetUseCaseProvider)
        .call(
          state.username,
          category: state.category,
          trackStories: state.isOn(TrackKind.stories),
          trackPosts: state.isOn(TrackKind.posts),
          trackReels: state.isOn(TrackKind.reels),
          note: state.note,
        );
    if (!ref.mounted) return result;
    state = switch (result) {
      AddTargetAdded() => state.copyWith(verifying: false, clearFailure: true),
      _ => state.copyWith(verifying: false, failure: result),
    };
    return result;
  }
}
