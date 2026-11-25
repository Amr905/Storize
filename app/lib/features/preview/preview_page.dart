import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/preview/preview_providers.dart';
import 'package:storize_app/features/targets/add_target_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

/// The profile preview (FR-74): the profile, the current stories and the first
/// page of posts of an account, loaded now. The user picks items and saves
/// them by hand, or starts tracking the account.
class PreviewPage extends ConsumerStatefulWidget {
  /// Creates the page for [args].
  const PreviewPage({required this.args, super.key});

  /// The account to preview.
  final PreviewArgs args;

  /// Opens the preview above the current screen.
  static Future<void> open(BuildContext context, PreviewArgs args) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => PreviewPage(args: args)),
      );

  @override
  ConsumerState<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends ConsumerState<PreviewPage> {
  PreviewController get _controller =>
      ref.read(previewControllerProvider(widget.args).notifier);

  Future<void> _save(List<RemoteContent> items) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await _controller.save(items);
    if (!mounted || result == null) return;
    final String text;
    if (result.failed == 0 && result.saved == 0) {
      text = l10n.prvSaveAlready;
    } else if (result.failed == 0) {
      text = l10n.prvSaveDone(result.saved);
    } else if (result.saved > 0 || result.alreadySaved > 0) {
      text = l10n.prvSavePartial(result.saved, result.failed);
    } else {
      final reason = result.items
          .map((i) => i.reason)
          .whereType<String>()
          .firstOrNull;
      text = l10n.prvSaveFailed(_reasonText(l10n, reason));
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _track() async {
    final state = ref.read(previewControllerProvider(widget.args));
    final router = GoRouter.maybeOf(context);
    final nav = Navigator.of(context);
    if (state.targetId != null && !state.targetTracked) {
      // Saved items made a preview-only target: tracking it is a switch, the
      // add form would call it a duplicate.
      final id = await _controller.activateTracking();
      if (!mounted || id == null) return;
      nav.pop();
      unawaited(router?.push(Routes.targetDetailLocation(id)));
      return;
    }
    await nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddTargetPage(initialUsername: widget.args.username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(previewControllerProvider(widget.args));
    final preview = state.preview;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prvTitle)),
      body: SafeArea(
        child: state.resolveFailure != null
            ? _ResolveError(
                failure: state.resolveFailure!,
                username: widget.args.username,
                onRetry: () => unawaited(_controller.load()),
              )
            : ListView(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: StorizeSpacing.screenMargin,
                  vertical: StorizeSpacing.s8,
                ),
                children: [
                  _Header(
                    username: widget.args.username,
                    user: preview?.user,
                  ),
                  const SizedBox(height: StorizeSpacing.s24),
                  _SectionTitle(l10n.prvCurrentStories),
                  const SizedBox(height: StorizeSpacing.s8),
                  _StoriesSection(
                    state: state,
                    onToggle: _controller.toggle,
                    onRetry: () => unawaited(_controller.load()),
                  ),
                  const SizedBox(height: StorizeSpacing.s24),
                  _SectionTitle(l10n.prvRecentPosts),
                  const SizedBox(height: StorizeSpacing.s8),
                  _PostsSection(
                    state: state,
                    onToggle: _controller.toggle,
                    onRetry: () => unawaited(_controller.load()),
                  ),
                  const SizedBox(height: StorizeSpacing.s16),
                ],
              ),
      ),
      bottomNavigationBar: preview == null
          ? null
          : _BottomBar(
              state: state,
              onSaveSelected: () => unawaited(_save(state.selectedUnsaved)),
              onSaveAll: () => unawaited(_save(state.unsaved)),
              onTrack: () => unawaited(_track()),
            ),
    );
  }
}

/// The save failure reason as a phrase for "Couldn't save: …".
String _reasonText(AppLocalizations l10n, String? reason) => switch (reason) {
  'busy' => l10n.prvReasonBusy,
  'storage_paused' => l10n.prvReasonStorage,
  'gallery_permission' => l10n.prvReasonPermission,
  'session' => l10n.prvReasonSession,
  _ => l10n.prvReasonGeneric,
};

/// The friendly message of [failure]: a title and an optional hint. It reuses
/// the strings of the add form and the error states.
({String title, String? body}) previewFailureText(
  AppLocalizations l10n,
  Failure failure,
  String username,
) => switch (failure) {
  NetworkFailure() => (
    title: l10n.errorNetworkTitle,
    body: l10n.errorNetworkBody,
  ),
  RateLimited() => (
    title: l10n.errorRateLimitedTitle,
    body: l10n.errorRateLimitedBody,
  ),
  SchemaChanged() => (
    title: l10n.errorPlatformChangedTitle,
    body: l10n.errorPlatformChangedBody,
  ),
  SessionInvalid() => (title: l10n.tgtSessionInactive, body: null),
  AccountRestricted() => (title: l10n.tgtRestricted, body: null),
  TargetNotFound() => (title: l10n.tgtNotFound('@$username'), body: null),
  TargetNotVisible() => (title: l10n.prvNotVisible, body: null),
  _ => (title: l10n.errorUnknownTitle, body: l10n.errorUnknownBody),
};

class _ResolveError extends StatelessWidget {
  const _ResolveError({
    required this.failure,
    required this.username,
    required this.onRetry,
  });

  final Failure failure;
  final String username;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = previewFailureText(l10n, failure, username);
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: text.title,
      body: text.body ?? '',
      actionLabel: l10n.retry,
      onAction: onRetry,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.username, required this.user});

  final String username;
  final RemoteUser? user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = user?.displayName;
    final avatar = user?.avatarUrl;
    return Row(
      children: [
        StorizeAvatar(
          initial: username.isEmpty ? '?' : username[0],
          size: 72,
          child: avatar == null
              ? null
              : PreviewImage(url: avatar, cacheWidth: 216),
        ),
        const SizedBox(width: StorizeSpacing.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name != null && name.isNotEmpty)
                Text(
                  name,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                '@${user?.username ?? username}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (user?.isPrivate ?? false)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: StorizeSpacing.s8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: StorizeSpacing.s4),
                      Text(
                        l10n.prvPrivateBadge,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.text, this.body, this.onRetry});

  final String text;
  final String? body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: theme.textTheme.bodyLarge),
              if (body != null)
                Text(
                  body!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (onRetry != null)
          StorizeTextButton(label: l10n.retry, onPressed: onRetry),
      ],
    );
  }
}

/// A saved item gets a check badge.
class _SavedBadge extends StatelessWidget {
  const _SavedBadge() : super(key: const ValueKey('prv-saved-badge'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = StorizeColors.of(context).success;
    return PositionedDirectional(
      end: StorizeSpacing.s8,
      top: StorizeSpacing.s8,
      child: Semantics(
        label: l10n.prvSavedBadge,
        child: DecoratedBox(
          decoration: BoxDecoration(color: tone.color, shape: BoxShape.circle),
          child: const Padding(
            padding: EdgeInsetsDirectional.all(StorizeSpacing.s4),
            child: Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _thumbContent(RemoteContent c) {
  final slide = c.slides.isEmpty ? null : c.slides.first;
  // The model has no poster URL for a video: only a photo has a picture.
  if (slide == null || slide.type == MediaType.video) {
    return const _VideoPlaceholder();
  }
  return PreviewImage(url: slide.url);
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Center(
      child: Icon(
        Icons.videocam_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

bool _isVideo(RemoteContent c) =>
    c.slides.isNotEmpty && c.slides.first.type == MediaType.video;

class _StoriesSection extends StatelessWidget {
  const _StoriesSection({
    required this.state,
    required this.onToggle,
    required this.onRetry,
  });

  final PreviewState state;
  final void Function(RemoteContent) onToggle;
  final VoidCallback onRetry;

  static const double _width = 96;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = state.preview;
    if (state.loading || preview == null) {
      return const _Loading(
        key: ValueKey('prv-stories-loading'),
        aspect: 9 / 16,
      );
    }
    final failure = preview.storiesFailure;
    if (failure != null) {
      final t = previewFailureText(l10n, failure, preview.user.username);
      return _SectionMessage(text: t.title, body: t.body, onRetry: onRetry);
    }
    if (preview.stories.isEmpty) {
      return _SectionMessage(text: l10n.prvNoStories);
    }
    return SizedBox(
      height: _width * 16 / 9,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: preview.stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: StorizeSpacing.s8),
        itemBuilder: (context, i) {
          final c = preview.stories[i];
          final key = previewItemKey(c);
          final saved = state.saved.contains(key);
          return SizedBox(
            width: _width,
            child: Stack(
              children: [
                StoryThumb(
                  key: ValueKey('prv-item-$key'),
                  semanticLabel: l10n.prvSelectItem,
                  content: _thumbContent(c),
                  isVideo: _isVideo(c),
                  selectionMode: !saved,
                  selected: state.selected.contains(key),
                  onTap: saved ? null : () => onToggle(c),
                ),
                if (saved) const _SavedBadge(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostsSection extends StatelessWidget {
  const _PostsSection({
    required this.state,
    required this.onToggle,
    required this.onRetry,
  });

  final PreviewState state;
  final void Function(RemoteContent) onToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = state.preview;
    if (state.loading || preview == null) {
      return const _Loading(key: ValueKey('prv-posts-loading'), aspect: 1);
    }
    final failure = preview.postsFailure;
    if (failure != null) {
      final t = previewFailureText(l10n, failure, preview.user.username);
      return _SectionMessage(text: t.title, body: t.body, onRetry: onRetry);
    }
    if (preview.posts.isEmpty) {
      return _SectionMessage(text: l10n.prvNoPosts);
    }
    final posts = preview.posts.take(12).toList();
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: StorizeSpacing.s8,
      crossAxisSpacing: StorizeSpacing.s8,
      children: [
        for (final c in posts)
          Builder(
            builder: (context) {
              final key = previewItemKey(c);
              final saved = state.saved.contains(key);
              return Stack(
                children: [
                  PostThumb(
                    key: ValueKey('prv-item-$key'),
                    semanticLabel: l10n.prvSelectItem,
                    content: _thumbContent(c),
                    carouselCount: c.slides.length,
                    isVideo: _isVideo(c),
                    selectionMode: !saved,
                    selected: state.selected.contains(key),
                    onTap: saved ? null : () => onToggle(c),
                  ),
                  if (saved) const _SavedBadge(),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.aspect, super.key});

  final double aspect;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).loading,
    child: SkeletonGrid(itemCount: 3, aspectRatio: aspect),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onSaveSelected,
    required this.onSaveAll,
    required this.onTrack,
  });

  final PreviewState state;
  final VoidCallback onSaveSelected;
  final VoidCallback onSaveAll;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = state.selectedUnsaved.length;
    final canSave = !state.loading && !state.saving;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: StorizeSpacing.screenMargin,
            vertical: StorizeSpacing.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TonalButton(
                      label: l10n.prvSaveSelected(selected),
                      expand: true,
                      onPressed: canSave && selected > 0
                          ? onSaveSelected
                          : null,
                    ),
                  ),
                  const SizedBox(width: StorizeSpacing.s12),
                  Expanded(
                    child: PrimaryButton(
                      label: state.saving ? l10n.prvSaving : l10n.prvSaveAll,
                      loading: state.saving,
                      expand: true,
                      onPressed: canSave && state.unsaved.isNotEmpty
                          ? onSaveAll
                          : null,
                    ),
                  ),
                ],
              ),
              if (state.targetTracked)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: StorizeSpacing.s8,
                    bottom: StorizeSpacing.s8,
                  ),
                  child: Text(
                    l10n.prvTracking,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                StorizeTextButton(label: l10n.prvTrack, onPressed: onTrack),
            ],
          ),
        ),
      ),
    );
  }
}

/// A network picture with a placeholder on error. CDN URLs are public; the
/// picture is cached by Flutter's image cache at the decoded [cacheWidth].
class PreviewImage extends StatelessWidget {
  /// Creates the picture.
  const PreviewImage({required this.url, this.cacheWidth = 360, super.key});

  /// The CDN URL.
  final String url;

  /// The decode width in pixels.
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => placeholder(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder(),
    );
  }
}
