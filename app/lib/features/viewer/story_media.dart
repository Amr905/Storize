import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/viewer/full_photo.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_app/features/viewer/story_video_player.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// One story on S-06: its photo or video, the edge taps that move between
/// stories, and the missing or broken states.
class StoryMediaView extends ConsumerStatefulWidget {
  /// Creates the view for [item].
  const StoryMediaView({
    required this.item,
    required this.active,
    required this.muted,
    required this.onPrevious,
    required this.onNext,
    required this.onRemove,
    required this.onProgress,
    super.key,
  });

  /// The story and its slide.
  final ContentWithMedia item;

  /// This is the story on screen: a video plays only when active.
  final bool active;

  /// The session's sound setting.
  final bool muted;

  /// Tap on the start edge.
  final VoidCallback onPrevious;

  /// Tap on the end edge.
  final VoidCallback onNext;

  /// The user chose "Remove from library" in a broken state.
  final VoidCallback onRemove;

  /// Playback fraction (0 to 1) of the current story, for the position bar.
  final ValueChanged<double> onProgress;

  @override
  ConsumerState<StoryMediaView> createState() => _StoryMediaViewState();
}

class _StoryMediaViewState extends ConsumerState<StoryMediaView> {
  /// The video could not be opened.
  bool _videoFailed = false;

  MediaFile? get _media =>
      widget.item.media.isEmpty ? null : widget.item.media.first;

  void _onTapUp(TapUpDetails d, double width) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = d.localPosition.dx;
    final startEdge = x < width * 0.3;
    final endEdge = x > width * 0.7;
    if (!startEdge && !endEdge) return;
    final previous = rtl ? endEdge : startEdge;
    if (previous) {
      widget.onPrevious();
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = _media;
    final uri = media?.contentUri;
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (media == null || uri == null) {
      body = _brokenView(l10n.storyMissingTitle, l10n.storyMissingBody);
    } else {
      final exists = ref.watch(storyFileExistsProvider(uri));
      body = exists.when(
        loading: () => _spinner(l10n),
        error: (_, _) =>
            _brokenView(l10n.storyMissingTitle, l10n.storyMissingBody),
        data: (ok) {
          if (!ok) {
            return _brokenView(l10n.storyMissingTitle, l10n.storyMissingBody);
          }
          if (_videoFailed) {
            return _brokenView(l10n.storyCantPlay, l10n.storyMissingBody);
          }
          if (media.mediaType == MediaType.video) {
            return _StoryVideo(
              key: ValueKey('video-${media.id}'),
              contentUri: uri,
              active: widget.active,
              muted: widget.muted,
              onProgress: widget.onProgress,
              onFailed: () {
                if (mounted) setState(() => _videoFailed = true);
              },
            );
          }
          return _StoryPhoto(media: media);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _onTapUp(d, constraints.maxWidth),
        child: ColoredBox(
          color: scheme.scrim,
          child: SizedBox.expand(child: body),
        ),
      ),
    );
  }

  Widget _spinner(AppLocalizations l10n) => Center(
    child: CircularProgressIndicator(semanticsLabel: l10n.storyLoading),
  );

  Widget _brokenView(String title, String body) {
    final l10n = AppLocalizations.of(context);
    final colors = StorizeColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(StorizeSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 48,
              color: colors.onMediaScrim,
            ),
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
            const SizedBox(height: StorizeSpacing.s16),
            FilledButton(
              onPressed: widget.onRemove,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, StorizeSpacing.minTouchTarget),
              ),
              child: Text(l10n.storyRemoveFromLibrary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A photo: the builder decides how it is drawn.
class _StoryPhoto extends ConsumerWidget {
  const _StoryPhoto({required this.media});

  final MediaFile media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(child: FullPhoto(media: media));
  }
}

/// A video with play/pause, mute and a scrubber. The player is behind
/// [StoryVideoPlayer], so tests use a fake.
class _StoryVideo extends ConsumerStatefulWidget {
  const _StoryVideo({
    required this.contentUri,
    required this.active,
    required this.muted,
    required this.onProgress,
    required this.onFailed,
    super.key,
  });

  final String contentUri;
  final bool active;
  final bool muted;
  final ValueChanged<double> onProgress;
  final VoidCallback onFailed;

  @override
  ConsumerState<_StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends ConsumerState<_StoryVideo> {
  late final StoryVideoPlayer _player;
  bool _ready = false;
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
      await _player.setMuted(widget.muted);
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.active) await _player.play();
    } on Object {
      if (mounted) widget.onFailed();
    }
  }

  void _onValue() {
    final v = _player.value.value;
    if (v.duration > Duration.zero) {
      widget.onProgress(
        v.position.inMilliseconds / v.duration.inMilliseconds,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_StoryVideo old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    if (old.active != widget.active) {
      unawaited(widget.active ? _player.play() : _player.pause());
    }
    if (old.muted != widget.muted) {
      unawaited(_player.setMuted(widget.muted));
    }
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
    if (!_ready) {
      return Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.storyLoading),
      );
    }
    final v = _player.value.value;
    final colors = StorizeColors.of(context);
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
