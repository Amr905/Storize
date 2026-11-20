import 'package:storize_instagram/mapper/node.dart';
import 'package:storize_model/storize_model.dart';

/// `RemoteContent.extras` key listing slide indexes that have only a DASH
/// stream (no progressive MP4). Those slides are left out of `slides`; the
/// downloader records them as `FAILED(unsupported_stream)` (TECH_SPEC 4.1).
const String unsupportedStreamKey = 'unsupported_stream';

/// `RemoteContent.extras` key for link stickers (stories).
const String linkStickersKey = 'link_stickers';

/// Maps one Instagram media object to `RemoteContent`.
///
/// The same media dictionary appears in story reels, in the timeline and in
/// `media/<pk>/info/`, whatever transport fetched it, so this mapper does not
/// know about transports. Unknown keys are ignored.
final class MediaMapper {
  /// Creates the mapper.
  const MediaMapper();

  /// Audience values that mean "close friends" (sanitizer known values).
  static const Set<String> _closeFriendsAudiences = {
    'besties',
    'close_friends',
  };

  /// Whether a story item is a live broadcast (dropped, FR-28).
  ///
  /// Synthetic and unverified: the capture has no live item. Matches
  /// `product_type` live, `is_live`, or a `broadcast_id`.
  bool isLive(Node item) {
    final product = item['product_type'].stringOrNull?.toLowerCase();
    return product == 'live' ||
        item['is_live'].boolOrNull == true ||
        !item['broadcast_id'].isNull;
  }

  /// Maps a story item. Returns null for a live item.
  RemoteContent? story(Node item) {
    if (isLive(item)) return null;
    _mediaType(item, allowCarousel: false);
    final slide = _slide(item, 0);
    final extras = <String, Object?>{
      if (_linkStickers(item) case final stickers when stickers.isNotEmpty)
        linkStickersKey: stickers,
      if (slide.unsupported) unsupportedStreamKey: const [0],
    };
    return RemoteContent(
      remoteId: item['pk'].string,
      kind: ContentKind.story,
      postedAt: item['taken_at'].unixTime,
      expiresAt: item['expiring_at'].unixTime,
      closeFriends: _closeFriends(item),
      slides: [?slide.media],
      extras: extras,
    );
  }

  /// Maps a post (a timeline node or a `media/info` item).
  ///
  /// [pinned] and [collab] only set markers in `extras`. `pinned` means
  /// "pinned by any user" (a co-author counts), not necessarily the profile
  /// owner.
  RemoteContent post(Node node, {bool pinned = false, bool collab = false}) {
    final kind = _mediaType(node, allowCarousel: true);
    final postedAt = node['taken_at'].unixTime;
    final slides = <RemoteMedia>[];
    final unsupported = <int>[];
    if (kind == _Kind.carousel) {
      final children = node['carousel_media'].list;
      if (children.isEmpty) throw SchemaException(node['carousel_media'].path);
      for (var i = 0; i < children.length; i++) {
        final slide = _slide(children[i], i);
        if (slide.media != null) slides.add(slide.media!);
        if (slide.unsupported) unsupported.add(i);
      }
    } else {
      final slide = _slide(node, 0);
      if (slide.media != null) slides.add(slide.media!);
      if (slide.unsupported) unsupported.add(0);
    }
    final product = node['product_type'].stringOrNull;
    final postType = switch (kind) {
      _Kind.photo => PostType.photo,
      _Kind.carousel => PostType.carousel,
      _Kind.video => product == 'clips' ? PostType.reel : PostType.video,
    };
    return RemoteContent(
      remoteId: node['pk'].string,
      kind: ContentKind.post,
      shortcode: node['code'].string,
      postType: postType,
      postedAt: postedAt,
      caption: node['caption']['text'].stringOrNull,
      slides: slides,
      extras: {
        if (pinned) 'pinned': true,
        if (collab) 'collab': true,
        if (unsupported.isNotEmpty) unsupportedStreamKey: unsupported,
      },
    );
  }

  _Kind _mediaType(Node item, {required bool allowCarousel}) {
    return switch (item['media_type'].integer) {
      1 => _Kind.photo,
      2 => _Kind.video,
      8 when allowCarousel => _Kind.carousel,
      _ => throw SchemaException(item['media_type'].path),
    };
  }

  bool _closeFriends(Node item) {
    final audience = item['audience'].stringOrNull?.toLowerCase();
    return audience != null && _closeFriendsAudiences.contains(audience);
  }

  /// Link stickers. The shape is unverified: each entry is expected to hold
  /// `story_link.url` (and maybe `link_title`). Entries without a URL are
  /// skipped instead of failing the whole item.
  List<Map<String, Object?>> _linkStickers(Node item) {
    final raw = item['story_link_stickers'];
    final v = raw.value;
    if (v is! List<Object?>) return const [];
    final out = <Map<String, Object?>>[];
    for (final entry in raw.list) {
      final link = entry['story_link'];
      final url = link['url'].value;
      if (url is! String || url.isEmpty) continue;
      final title = link['link_title'].value;
      out.add({
        'url': url,
        if (title is String && title.isNotEmpty) 'title': title,
      });
    }
    return out;
  }

  /// The best rendition of a single image or video object (a story item, a
  /// post, or a carousel child).
  _Slide _slide(Node item, int index) {
    final isVideo = item['media_type'].integer == 2;
    final cover = _bestImage(item['image_versions2']['candidates']);
    if (!isVideo) {
      if (cover == null) {
        throw SchemaException(item['image_versions2']['candidates'].path);
      }
      return _Slide(
        RemoteMedia(
          index: index,
          type: MediaType.photo,
          url: cover.url,
          width: cover.width,
          height: cover.height,
        ),
      );
    }
    final video = _bestVideo(item['video_versions']);
    if (video == null) {
      final manifest = item['video_dash_manifest'].stringOrNull;
      if (manifest != null && manifest.isNotEmpty) {
        return const _Slide(null, unsupported: true);
      }
      throw SchemaException(item['video_versions'].path);
    }
    final width =
        video.widthOrNull ??
        item['original_width'].intOrNull ??
        cover?.width ??
        0;
    final height =
        video.heightOrNull ??
        item['original_height'].intOrNull ??
        cover?.height ??
        0;
    final seconds = item['video_duration'].numOrNull;
    return _Slide(
      RemoteMedia(
        index: index,
        type: MediaType.video,
        url: video.url,
        width: width,
        height: height,
        duration: seconds == null
            ? null
            : Duration(milliseconds: (seconds * 1000).round()),
      ),
    );
  }

  /// Largest `width * height`; the first one wins a tie. Entries without a
  /// URL or size are skipped.
  _Candidate? _bestImage(Node candidates) {
    _Candidate? best;
    for (final c in candidates.listOrEmpty) {
      final url = c['url'].value;
      final w = c['width'].intOrNull;
      final h = c['height'].intOrNull;
      if (url is! String || url.isEmpty || w == null || h == null) continue;
      if (best == null || w * h > best.area) {
        best = _Candidate(url, w, h);
      }
    }
    return best;
  }

  /// Progressive MP4 only (`video_versions`). With sizes: the largest area,
  /// the first wins a tie. Without sizes (story versions): the first entry,
  /// which is the order Instagram lists them in. How `type` 101/102/103 maps
  /// to quality is unverified (INSTAGRAM_EXTRACTION.md).
  _Candidate? _bestVideo(Node versions) {
    _Candidate? best;
    for (final v in versions.listOrEmpty) {
      final url = v['url'].value;
      if (url is! String || url.isEmpty) continue;
      final candidate = _Candidate(
        url,
        v['width'].intOrNull,
        v['height'].intOrNull,
      );
      if (best == null || candidate.area > best.area) best = candidate;
    }
    return best;
  }
}

enum _Kind { photo, video, carousel }

final class _Candidate {
  const _Candidate(this.url, int? width, int? height)
    : _width = width,
      _height = height;

  final String url;
  final int? _width;
  final int? _height;

  int get width => _width ?? 0;
  int get height => _height ?? 0;

  /// Nullable views for video fallbacks.
  int? get widthOrNull => _width;
  int? get heightOrNull => _height;

  int get area => width * height;
}

final class _Slide {
  const _Slide(this.media, {this.unsupported = false});

  final RemoteMedia? media;
  final bool unsupported;
}
