import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// S-08: adds a tracked account with its category and tracks (FR-10, FR-16,
/// FR-63, FR-65, FR-67, BR-1, BR-2).
class AddTargetPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AddTargetPage({super.key});

  @override
  ConsumerState<AddTargetPage> createState() => _AddTargetPageState();
}

class _AddTargetPageState extends ConsumerState<AddTargetPage> {
  final _username = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = await ref.read(addTargetFormProvider.notifier).submit();
    if (!mounted || result == null) return;
    _handle(result);
  }

  /// Side effects of a result. Errors that belong to a field are shown inline
  /// by [build] from the form state, so they need no action here.
  void _handle(AddTargetResult result) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case AddTargetAdded(:final target):
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.tgtAdded(target.username))),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.targetsPath);
        }
      case AddTargetInvalidUsername():
      case AddTargetMissingCategory():
      case AddTargetNoTrackFlag():
      case AddTargetNoteTooLong():
      case AddTargetNotFound():
      case AddTargetNotVisible():
      case AddTargetDuplicate():
      case AddTargetSessionNotActive():
        // Shown inline (see _AddTargetPageState._usernameError and friends).
        break;
      case AddTargetAccountRestricted():
        messenger.showSnackBar(SnackBar(content: Text(l10n.tgtRestricted)));
      case AddTargetRateLimited():
        // Shown inline, the form stays editable (TECH_SPEC 17.3).
        break;
      case AddTargetNetwork():
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.errorNetworkTitle),
            action: SnackBarAction(
              label: l10n.retry,
              onPressed: () => unawaited(_submit()),
            ),
          ),
        );
      case AddTargetSchemaChanged():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorPlatformChangedTitle)),
        );
      case AddTargetUnknown():
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorUnknownTitle)));
    }
  }

  /// The inline username error, from the server result or the local rules.
  static String? _usernameError(
    AppLocalizations l10n,
    AddTargetForm form,
    String login,
  ) {
    final failure = form.failure;
    final normalized = form.normalized;
    if (failure is AddTargetNotFound && normalized != null) {
      return l10n.tgtNotFound('@$normalized');
    }
    if (failure is AddTargetNotVisible) {
      return failure.reason == NotVisibleReason.privateNotFollowed
          ? l10n.tgtNotVisiblePrivate(
              '@${normalized ?? form.username}',
              '@$login',
            )
          : l10n.tgtNotVisibleBlocked('@${normalized ?? form.username}');
    }
    if (failure is AddTargetDuplicate) {
      return l10n.tgtDuplicate('@${failure.existingUsername}');
    }
    if (failure is AddTargetRateLimited) {
      final minutes = ((failure.retryAfter?.inSeconds ?? 0) / 60).ceil();
      return l10n.tgtErrRateLimited(minutes < 1 ? 1 : minutes);
    }
    final invalid = normalized == null;
    if (invalid && (form.submitted || form.username.isNotEmpty)) {
      return l10n.tgtUsernameInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(addTargetFormProvider);
    final notifier = ref.read(addTargetFormProvider.notifier);
    final sessionActive = ref.watch(targetsSessionActiveProvider);
    final count = ref.watch(targetsProvider).value?.length ?? 0;
    final verifying = form.verifying;
    final login = ref.watch(targetsLoginNameProvider).value ?? '';
    final usernameError = _usernameError(l10n, form, login);
    final failure = form.failure;
    final categoryError = form.submitted && form.category == null
        ? l10n.tgtCategoryRequired
        : null;
    final trackError = form.trackRejected ? l10n.tgtTrackRequired : null;
    final sessionMessage = !sessionActive ? l10n.tgtSessionInactive : null;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.titleSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: color, width: width),
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.tgtClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.targetsPath);
            }
          },
        ),
        title: Text(l10n.tgtFormTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(StorizeSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (count >= TargetLimits.recommendedMax)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: StorizeSpacing.s16,
                  ),
                  child: _Notice(
                    icon: Icons.warning_amber_rounded,
                    text: l10n.tgtOverLimit(TargetLimits.recommendedMax),
                    tone: StorizeColors.of(context).warning,
                  ),
                ),
              Text(l10n.tgtUsernameLabel, style: labelStyle),
              const SizedBox(height: StorizeSpacing.s12),
              TextField(
                controller: _username,
                enabled: !verifying,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                onChanged: notifier.setUsername,
                decoration: InputDecoration(
                  hintText: l10n.tgtUsernameHint,
                  prefixText: '@ ',
                  prefixStyle: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: StorizeSpacing.s16,
                    vertical: StorizeSpacing.s20,
                  ),
                  enabledBorder: border(
                    usernameError == null ? scheme.outline : scheme.error,
                  ),
                  focusedBorder: border(
                    usernameError == null ? scheme.primary : scheme.error,
                    width: 2,
                  ),
                  disabledBorder: border(scheme.outline),
                  errorBorder: border(scheme.error),
                  focusedErrorBorder: border(scheme.error, width: 2),
                ),
              ),
              if (usernameError != null)
                _ErrorText(
                  usernameError,
                  color: scheme.error,
                  icon: Icons.warning_amber_rounded,
                ),
              if (failure is AddTargetDuplicate)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StorizeTextButton(
                    label: l10n.tgtOpen,
                    onPressed: () => unawaited(
                      context.push(
                        Routes.targetDetailLocation(failure.existingId),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: StorizeSpacing.s16),
              Text(l10n.tgtCategoryLabel, style: labelStyle),
              const SizedBox(height: StorizeSpacing.s12),
              IgnorePointer(
                ignoring: verifying,
                child: RadioGroup<TargetCategory>(
                  groupValue: form.category,
                  onChanged: verifying
                      ? (_) {}
                      : (value) {
                          if (value != null) notifier.selectCategory(value);
                        },
                  child: Column(
                    children: [
                      for (final c in TargetCategory.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            bottom: StorizeSpacing.s12,
                          ),
                          child: Material(
                            color: form.category == c
                                ? scheme.primaryContainer.withValues(
                                    alpha: 0.35,
                                  )
                                : scheme.surfaceContainerLowest,
                            shape: RoundedRectangleBorder(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(14),
                              ),
                              side: BorderSide(
                                color: form.category == c
                                    ? scheme.primary
                                    : scheme.outline,
                              ),
                            ),
                            child: RadioListTile<TargetCategory>(
                              contentPadding: const EdgeInsetsDirectional.only(
                                start: StorizeSpacing.s8,
                                end: StorizeSpacing.s16,
                              ),
                              minTileHeight: 0,
                              value: c,
                              title: Text(
                                _categoryTitle(l10n, c),
                                style: textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                _categoryHint(l10n, c),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (categoryError != null)
                _ErrorText(categoryError, color: scheme.error),
              const SizedBox(height: StorizeSpacing.s16),
              Text(l10n.tgtTrackLabel, style: labelStyle),
              const SizedBox(height: StorizeSpacing.s8),
              Wrap(
                spacing: StorizeSpacing.s8,
                children: [
                  for (final kind in TrackKind.values)
                    FilterChip(
                      label: Text(_trackLabel(l10n, kind)),
                      selected: form.isOn(kind),
                      onSelected: verifying
                          ? null
                          : (_) => notifier.toggleTrack(kind),
                    ),
                ],
              ),
              const SizedBox(height: StorizeSpacing.s4),
              if (trackError != null)
                _ErrorText(trackError, color: scheme.error),
              Text(
                l10n.tgtTrackHint,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: StorizeSpacing.s16),
              Text(l10n.tgtNoteLabel, style: labelStyle),
              const SizedBox(height: StorizeSpacing.s12),
              TextField(
                controller: _note,
                enabled: !verifying,
                maxLength: TargetLimits.noteMaxLength,
                maxLines: 2,
                onChanged: notifier.setNote,
                decoration: InputDecoration(
                  hintText: l10n.tgtNoteHint,
                  errorText: form.noteTooLong ? l10n.tgtNoteTooLong : null,
                  contentPadding: const EdgeInsetsDirectional.all(
                    StorizeSpacing.s16,
                  ),
                  enabledBorder: border(scheme.outline),
                  focusedBorder: border(scheme.primary, width: 2),
                  disabledBorder: border(scheme.outline),
                  errorBorder: border(scheme.error),
                  focusedErrorBorder: border(scheme.error, width: 2),
                ),
              ),
              const SizedBox(height: StorizeSpacing.s24),
              if (sessionMessage != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: StorizeSpacing.s16,
                  ),
                  child: _Notice(
                    icon: Icons.lock_outline_rounded,
                    text: sessionMessage,
                    tone: StorizeColors.of(context).error,
                  ),
                ),
              PrimaryButton(
                label: verifying ? l10n.tgtVerifying : l10n.tgtAddAndVerify,
                loading: verifying,
                expand: true,
                onPressed: sessionActive && !verifying
                    ? () => unawaited(_submit())
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _categoryTitle(AppLocalizations l10n, TargetCategory c) =>
      switch (c) {
        TargetCategory.ownClient => l10n.tgtCatOwnTitle,
        TargetCategory.consented => l10n.tgtCatConsented,
        TargetCategory.public => l10n.tgtCatPublic,
      };

  static String _categoryHint(AppLocalizations l10n, TargetCategory c) =>
      switch (c) {
        TargetCategory.ownClient => l10n.tgtCatOwnHint,
        TargetCategory.consented => l10n.tgtCatConsentedHint,
        TargetCategory.public => l10n.tgtCatPublicHint,
      };

  static String _trackLabel(AppLocalizations l10n, TrackKind kind) =>
      switch (kind) {
        TrackKind.stories => l10n.tgtTrackStories,
        TrackKind.posts => l10n.tgtTrackPosts,
        TrackKind.reels => l10n.tgtTrackReels,
      };
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text, {required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: StorizeSpacing.s8),
      child: icon == null
          ? Text(text, style: style)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: StorizeSpacing.s8),
                Expanded(child: Text(text, style: style)),
              ],
            ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final StorizeTone tone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tone.container,
      borderRadius: StorizeRadii.chipRadius,
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.all(StorizeSpacing.s12),
      child: Row(
        children: [
          Icon(icon, color: tone.color),
          const SizedBox(width: StorizeSpacing.s8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tone.onContainer),
            ),
          ),
        ],
      ),
    ),
  );
}
