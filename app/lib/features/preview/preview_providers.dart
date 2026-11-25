import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The preview use case (FR-74). Wired by the composition root.
final previewProfileProvider = Provider<PreviewProfile>(
  (ref) => throw UnimplementedError('previewProfileProvider is not wired'),
);

/// The save use case of the preview (FR-74). Wired by the composition root.
final savePreviewItemsProvider = Provider<SavePreviewItems>(
  (ref) => throw UnimplementedError('savePreviewItemsProvider is not wired'),
);

/// Which account a preview shows.
@immutable
class PreviewArgs {
  /// Creates the arguments. [targetId] is set when the preview is opened from
  /// a tracked account (S-09).
  const PreviewArgs({required this.username, this.targetId});

  /// The username to preview (no `@`).
  final String username;

  /// The tracked target, or null for an account that is not tracked.
  final int? targetId;

  @override
  bool operator ==(Object other) =>
      other is PreviewArgs &&
      other.username == username &&
      other.targetId == targetId;

  @override
  int get hashCode => Object.hash(username, targetId);
}

/// The identity of one previewed item.
String previewItemKey(RemoteContent c) => '${c.kind.name}:${c.remoteId}';

/// The state of the preview screen.
@immutable
class PreviewState {
  /// Creates the state.
  const PreviewState({
    this.loading = true,
    this.resolveFailure,
    this.preview,
    this.selected = const {},
    this.saved = const {},
    this.saving = false,
    this.targetId,
    this.targetTracked = false,
  });

  /// True until the profile, the stories and the posts have answered.
  final bool loading;

  /// Why the account could not be resolved, or null.
  final Failure? resolveFailure;

  /// What was loaded, or null while loading or when resolving failed.
  final ProfilePreview? preview;

  /// The keys ([previewItemKey]) the user ticked.
  final Set<String> selected;

  /// The keys that are in the gallery.
  final Set<String> saved;

  /// True while a save runs.
  final bool saving;

  /// The target the items are stored under, once there is one.
  final int? targetId;

  /// Whether that target is tracked (not a preview-only target).
  final bool targetTracked;

  /// Every item of the preview, stories first.
  List<RemoteContent> get items => [
    ...?preview?.stories,
    ...?preview?.posts,
  ];

  /// The items that are not saved yet.
  List<RemoteContent> get unsaved => [
    for (final c in items)
      if (!saved.contains(previewItemKey(c))) c,
  ];

  /// The ticked items that are not saved yet.
  List<RemoteContent> get selectedUnsaved => [
    for (final c in unsaved)
      if (selected.contains(previewItemKey(c))) c,
  ];

  /// A copy with the given fields replaced.
  PreviewState copyWith({
    bool? loading,
    Object? resolveFailure = _unset,
    ProfilePreview? preview,
    Set<String>? selected,
    Set<String>? saved,
    bool? saving,
    int? targetId,
    bool? targetTracked,
  }) => PreviewState(
    loading: loading ?? this.loading,
    resolveFailure: identical(resolveFailure, _unset)
        ? this.resolveFailure
        : resolveFailure as Failure?,
    preview: preview ?? this.preview,
    selected: selected ?? this.selected,
    saved: saved ?? this.saved,
    saving: saving ?? this.saving,
    targetId: targetId ?? this.targetId,
    targetTracked: targetTracked ?? this.targetTracked,
  );
}

const Object _unset = Object();

/// The preview of one account. Auto-disposed: every visit loads again.
final NotifierProviderFamily<PreviewController, PreviewState, PreviewArgs>
previewControllerProvider = NotifierProvider.autoDispose
    .family<PreviewController, PreviewState, PreviewArgs>(
      PreviewController.new,
    );

/// Loads the preview and runs the saves of one account.
class PreviewController extends Notifier<PreviewState> {
  /// Creates the controller for [args].
  PreviewController(this.args);

  /// The account.
  final PreviewArgs args;

  @override
  PreviewState build() {
    unawaited(Future<void>.microtask(load));
    return PreviewState(targetId: args.targetId);
  }

  /// Loads (or reloads) the profile, the stories and the first posts.
  Future<void> load() async {
    state = state.copyWith(loading: true, resolveFailure: null);
    final result = await ref.read(previewProfileProvider).run(args.username);
    if (!ref.mounted) return;
    switch (result) {
      case Err(:final failure):
        state = state.copyWith(loading: false, resolveFailure: failure);
      case Ok(:final value):
        final known = await _knownSaved(value);
        if (!ref.mounted) return;
        state = state.copyWith(
          loading: false,
          resolveFailure: null,
          preview: value,
          saved: known.saved,
          targetId: known.target?.id ?? state.targetId,
          targetTracked: known.target != null
              ? !SavePreviewItems.isPreviewOnly(known.target!)
              : state.targetTracked,
        );
    }
  }

  /// Items of this preview that the gallery already has.
  Future<({Target? target, Set<String> saved})> _knownSaved(
    ProfilePreview p,
  ) async {
    try {
      final targets = ref.read(targetRepoProvider);
      final target =
          (args.targetId == null
              ? null
              : await targets.getById(args.targetId!)) ??
          await targets.getByRemoteUserId(
            PlatformId.instagram,
            p.user.remoteUserId,
          );
      if (target == null) return (target: null, saved: const <String>{});
      final stored = await ref
          .read(contentRepoProvider)
          .listByTarget(target.id);
      final done = {
        for (final c in stored)
          if (c.content.status == ContentStatus.done)
            '${c.content.kind.name}:${c.content.remoteId}',
      };
      return (
        target: target,
        saved: {
          for (final c in [...p.stories, ...p.posts])
            if (done.contains(previewItemKey(c))) previewItemKey(c),
        },
      );
    } on Object {
      return (target: null, saved: const <String>{});
    }
  }

  /// Ticks or unticks [item].
  void toggle(RemoteContent item) {
    final key = previewItemKey(item);
    final next = {...state.selected};
    if (!next.remove(key)) next.add(key);
    state = state.copyWith(selected: next);
  }

  /// Saves [items] now. Returns the result, or null when nothing was asked
  /// or a save is running.
  Future<PreviewSaveResult?> save(List<RemoteContent> items) async {
    final user = state.preview?.user;
    if (user == null || items.isEmpty || state.saving) return null;
    state = state.copyWith(saving: true);
    try {
      final result = await ref
          .read(savePreviewItemsProvider)
          .call(user: user, items: items, targetId: state.targetId);
      if (!ref.mounted) return result;
      final okKeys = {
        for (final r in result.items)
          if (r.status != PreviewSaveStatus.failed)
            '${r.kind.name}:${r.remoteId}',
      };
      state = state.copyWith(
        saving: false,
        saved: {...state.saved, ...okKeys},
        selected: {...state.selected}..removeAll(okKeys),
        targetId: result.target.id,
        targetTracked: !SavePreviewItems.isPreviewOnly(result.target),
      );
      return result;
    } on Object {
      if (ref.mounted) state = state.copyWith(saving: false);
      return null;
    }
  }

  /// Starts normal tracking of the preview-only target, when there is one.
  /// Returns its id, or null when the account has no stored target yet.
  Future<int?> activateTracking() async {
    final id = state.targetId;
    if (id == null) return null;
    final t = await ref
        .read(savePreviewItemsProvider)
        .activatePreviewTarget(id);
    if (ref.mounted) state = state.copyWith(targetTracked: true);
    return t.id;
  }
}
