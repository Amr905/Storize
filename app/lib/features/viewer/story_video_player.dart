import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// What the S-06 video controls need to know about a player.
@immutable
class StoryVideoValue {
  /// Creates a value.
  const StoryVideoValue({
    this.initialized = false,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.hasError = false,
    this.aspectRatio = 9 / 16,
  });

  /// The media is ready to play.
  final bool initialized;

  /// The media is playing now.
  final bool playing;

  /// The playback position.
  final Duration position;

  /// The media length (zero until known).
  final Duration duration;

  /// Playback failed.
  final bool hasError;

  /// Width over height of the video (9:16 until known).
  final double aspectRatio;

  @override
  bool operator ==(Object other) =>
      other is StoryVideoValue &&
      other.initialized == initialized &&
      other.playing == playing &&
      other.position == position &&
      other.duration == duration &&
      other.hasError == hasError &&
      other.aspectRatio == aspectRatio;

  @override
  int get hashCode => Object.hash(
    initialized,
    playing,
    position,
    duration,
    hasError,
    aspectRatio,
  );
}

/// A video player behind an interface, so tests use a fake and never touch
/// the platform. The default wraps `video_player`.
abstract interface class StoryVideoPlayer {
  /// Current state; listen for changes.
  ValueListenable<StoryVideoValue> get value;

  /// Prepares the media. Throws when it cannot be opened.
  Future<void> initialize();

  /// Starts playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Moves to [position].
  Future<void> seekTo(Duration position);

  /// Mutes or unmutes the sound.
  Future<void> setMuted(bool muted);

  /// The video surface.
  Widget buildSurface(BuildContext context);

  /// Releases the player.
  Future<void> dispose();
}

/// Makes a [StoryVideoPlayer] for a gallery `contentUri`.
typedef StoryVideoPlayerFactory = StoryVideoPlayer Function(String contentUri);

/// The default player, backed by `video_player` (Android content URIs).
final class VideoPlayerStoryPlayer implements StoryVideoPlayer {
  /// Creates a player for [contentUri]. Nothing is opened until
  /// [initialize].
  VideoPlayerStoryPlayer(String contentUri)
    : _controller = VideoPlayerController.contentUri(Uri.parse(contentUri));

  final VideoPlayerController _controller;
  final ValueNotifier<StoryVideoValue> _value = ValueNotifier(
    const StoryVideoValue(),
  );
  bool _muted = false;

  @override
  ValueListenable<StoryVideoValue> get value => _value;

  @override
  Future<void> initialize() async {
    _controller.addListener(_sync);
    await _controller.initialize();
    await _controller.setVolume(_muted ? 0 : 1);
    _sync();
  }

  void _sync() {
    final v = _controller.value;
    _value.value = StoryVideoValue(
      initialized: v.isInitialized,
      playing: v.isPlaying,
      position: v.position,
      duration: v.duration,
      hasError: v.hasError,
      aspectRatio: v.aspectRatio,
    );
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await _controller.setVolume(muted ? 0 : 1);
  }

  @override
  Widget buildSurface(BuildContext context) => VideoPlayer(_controller);

  @override
  Future<void> dispose() async {
    _controller.removeListener(_sync);
    await _controller.dispose();
    _value.dispose();
  }
}
