import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_app/features/viewer/story_video_player.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// One slide of a post on S-15. A photo zooms; a video has play/pause and a
/// scrubber. A slide whose file is gone (EC-20) or never downloaded (EC-21)
/// shows its own message, and the other slides are unaffected.
class PostSlideView extends ConsumerWidget {
  /// Creates the view for [media] of content [contentId].
  const PostSlideView({
    required this.contentId,
    required this.media,
    required this.onRemove,
    super.key,
  });

  /// The post that owns the slide.
  final int contentId;

  /// The slide.
  final MediaFile media;

  /// The user chose "Remove slide" in the missing state.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uri = media.contentUri;
    final downloaded = media.status == MediaFileStatus.done && uri != null;

    if (media.status == MediaFileStatus.fileMissing) {
      return _missing(context, l10n);
    }
    if (!downloaded) {
      return _notDownloaded(context, l10n);
    }
    final exists = ref.watch(storyFileExistsProvider(uri));
    return exists.when(
      loading: () => _spinner(l10n),
      error: (_, _) => _missing(context, l10n),
      data: (ok) {
        if (!ok) return _missing(context, l10n);
        if (media.mediaType == MediaType.video) {
          return _PostVideo(
            key: ValueKey('post-video-${media.id}'),
            contentUri: uri,
          );
        }
        return _PostPhoto(media: media);
      },
    );
  }

  Widget _spinner(AppLocalizations l10n) => Center(
    child: CircularProgressIndicator(semanticsLabel: l10n.storyLoading),
  );

  Widget _missing(BuildContext context, AppLocalizations l10n) => _Message(
    icon: Icons.broken_image_rounded,
    title: l10n.postSlideMissingTitle,
    body: l10n.postSlideMissingBody,
    actionLabel: l10n.postRemoveSlide,
    onAction: onRemove,
  );

  Widget _notDownloaded(BuildContext context, AppLocalizations l10n) =>
      _Message(
        icon: Icons.cloud_off_rounded,
        title: l10n.postSlideNotDownloaded,
        body: l10n.postSlideNotDownloadedBody,
      );
}

/// A centred icon, title and body, with an optional action.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = StorizeColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(StorizeSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.onMediaScrim),
            const SizedBox(height: StorizeSpacing.s12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: colors.onMediaScrim),
            ),
            const SizedBox(height: StorizeSpacing.s8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.onMediaScrim),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: StorizeSpacing.s16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, StorizeSpacing.minTouchTarget),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A photo that can be zoomed. The builder decides how it is drawn (the
/// cached preview for now).
class _PostPhoto extends ConsumerWidget {
  const _PostPhoto({required this.media});

  final MediaFile media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (media.thumbPath == null) {
      return Center(
        child: Text(
          l10n.storyPhotoUnavailable,
          style: TextStyle(color: StorizeColors.of(context).onMediaScrim),
        ),
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: ref.watch(storyPhotoBuilderProvider)(context, media),
      ),
    );
  }
}

/// A video with play/pause and a scrubber. The player is behind
/// [StoryVideoPlayer], so tests use a fake.
class _PostVideo extends ConsumerStatefulWidget {
  const _PostVideo({required this.contentUri, super.key});

  final String contentUri;

  @override
  ConsumerState<_PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends ConsumerState<_PostVideo> {
  late final StoryVideoPlayer _player;
  bool _ready = false;
  bool _failed = false;
  double? _dragMs;

  @override
  void initState() {
    super.initState();
    _player = ref.read(storyVideoPlayerFactoryProvider)(widget.contentUri);
    _player.value.addListener(_onValue);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _player.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onValue() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player.value.removeListener(_onValue);
    unawaited(_player.dispose());
    super.dispose();
  }

  String _clock(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = StorizeColors.of(context);
    if (_failed) {
      return Center(
        child: Text(
          l10n.storyCantPlay,
          style: TextStyle(color: colors.onMediaScrim),
        ),
      );
    }
    if (!_ready) {
      return Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.storyLoading),
      );
    }
    final v = _player.value.value;
    final durationMs = v.duration.inMilliseconds;
    final posMs = v.position.inMilliseconds.toDouble();
    final sliderValue = (_dragMs ?? posMs).clamp(
      0.0,
      durationMs == 0 ? 1.0 : durationMs.toDouble(),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: AspectRatio(
              aspectRatio: v.aspectRatio,
              child: _player.buildSurface(context),
            ),
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StorizeSpacing.s8,
            ),
            child: Row(
              children: [
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: StorizeSpacing.minTouchTarget,
                    minHeight: StorizeSpacing.minTouchTarget,
                  ),
                  tooltip: v.playing ? l10n.storyPause : l10n.storyPlay,
                  color: colors.onMediaScrim,
                  icon: Icon(
                    v.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: () => v.playing ? _player.pause() : _player.play(),
                ),
                Text(
                  _clock(v.position),
                  style: TextStyle(color: colors.onMediaScrim),
                ),
                Expanded(
                  child: Semantics(
                    label: l10n.storyScrubber,
                    child: Slider(
                      min: 0,
                      max: durationMs == 0 ? 1 : durationMs.toDouble(),
                      value: sliderValue,
                      activeColor: colors.onMediaScrim,
                      onChanged: (x) => setState(() => _dragMs = x),
                      onChangeEnd: (x) {
                        setState(() => _dragMs = null);
                        unawaited(
                          _player.seekTo(Duration(milliseconds: x.round())),
                        );
                      },
                    ),
                  ),
                ),
                Text(
                  _clock(v.duration),
                  style: TextStyle(color: colors.onMediaScrim),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
