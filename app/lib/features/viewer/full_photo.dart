import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// A photo of S-06 or S-15 at full size.
///
/// The thumbnail (through [storyPhotoBuilderProvider]) shows while the bytes
/// load and whenever they cannot be read or decoded (too big, file gone).
class FullPhoto extends ConsumerWidget {
  /// Creates the view for [media], which must be a downloaded photo.
  const FullPhoto({required this.media, super.key});

  /// The slide.
  final MediaFile media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = media.contentUri;
    final bytes = uri == null
        ? null
        : ref.watch(fullPhotoBytesProvider(uri)).value;
    final fallback = _thumbnail(context, ref);
    if (bytes == null) return fallback;
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
      // Show the thumbnail until the first frame is decoded.
      frameBuilder: (_, child, frame, sync) =>
          frame == null && !sync ? fallback : child,
    );
  }

  Widget _thumbnail(BuildContext context, WidgetRef ref) {
    if (media.thumbPath == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).storyPhotoUnavailable,
          style: TextStyle(color: StorizeColors.of(context).onMediaScrim),
        ),
      );
    }
    return ref.watch(storyPhotoBuilderProvider)(context, media);
  }
}
