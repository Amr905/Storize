import 'package:storize_instagram/mapper/media_mapper.dart';
import 'package:storize_instagram/mapper/node.dart';
import 'package:storize_instagram/mapper/user_mapper.dart';
import 'package:storize_model/storize_model.dart';

/// The id of a highlight without the `highlight:` prefix.
String stripHighlightPrefix(String id) =>
    id.startsWith('highlight:') ? id.substring('highlight:'.length) : id;

/// The stories of one user from a reels response.
final class StoryReel {
  /// Creates a reel.
  const StoryReel({
    required this.userId,
    required this.items,
    this.latestReelMedia,
  });

  /// The owner (the reel id equals the owner's user id).
  final String userId;

  /// The newest-item time the reel reports, when present.
  final DateTime? latestReelMedia;

  /// Mapped story items, live items dropped, oldest first.
  final List<RemoteContent> items;
}

/// One post of a timeline response, with what change detection needs. The
/// full mapping is deferred until the entry is known to be new.
final class TimelineEntry {
  /// Creates an entry.
  const TimelineEntry({
    required this.node,
    required this.pk,
    required this.takenAt,
    required this.pinned,
    required this.authorIds,
    required this.coauthorIds,
  });

  /// The media object.
  final Node node;

  /// The media id.
  final String pk;

  /// When the post was published.
  final DateTime takenAt;

  /// Whether the post is pinned (`timeline_pinned_user_ids` is not empty).
  /// It means "pinned by any user", for example a co-author of a collab
  /// post, not only by the profile owner. It never affects which posts are
  /// returned; it is only a marker.
  final bool pinned;

  /// `user.pk` and `owner_id.pk`. On a collab post this is the other author.
  final Set<String> authorIds;

  /// `coauthor_producers[].pk`.
  final Set<String> coauthorIds;

  /// Whether the post counts for [userId]: authored by them, or a collab post
  /// that lists them as a co-author (AC8).
  bool belongsTo(String userId) =>
      authorIds.contains(userId) || coauthorIds.contains(userId);

  /// Whether this is a collab post of [userId] authored by someone else.
  bool isCollabOf(String userId) =>
      !authorIds.contains(userId) && coauthorIds.contains(userId);
}

/// A timeline page.
final class Timeline {
  /// Creates a timeline.
  const Timeline({
    required this.entries,
    this.viewerId,
    this.usernameUsed,
    this.skippedMalformed = 0,
    this.endCursor,
    this.hasNextPage,
  });

  /// `page_info.end_cursor` of the connection, when present (GraphQL only).
  final String? endCursor;

  /// `page_info.has_next_page`, or null when the response did not say.
  final bool? hasNextPage;

  /// How many edges were left out because their `pk` or `taken_at` was
  /// missing or broken. The page fails only when every edge is malformed.
  final int skippedMalformed;

  /// The posts, in the order Instagram lists them (pinned first; not date
  /// order).
  final List<TimelineEntry> entries;

  /// The logged-in user id, when the response carries it.
  final String? viewerId;

  /// The username the request used (GraphQL transport), for caching.
  final String? usernameUsed;
}

/// Parsed answer to "who am I".
final class Viewer {
  /// Creates a viewer.
  const Viewer({required this.viewerId, required this.profile});

  /// The logged-in user id.
  final String viewerId;

  /// The logged-in user, when the response carries it.
  final UserProfile? profile;
}

/// Reads the response envelopes of both transports into transport-neutral
/// values. Media and users go through [MediaMapper] and [UserMapper].
///
/// GraphQL envelopes were observed. REST envelopes (IG-1 to IG-5) were not:
/// their shapes follow the TECH_SPEC candidate table and are **unverified**
/// until the live probe passes.
final class EnvelopeMapper {
  /// Creates the mapper.
  const EnvelopeMapper({
    this.media = const MediaMapper(),
    this.users = const UserMapper(),
  });

  /// The media mapper.
  final MediaMapper media;

  /// The user mapper.
  final UserMapper users;

  // ------------------------------------------------------------- GraphQL

  /// `PolarisProfilePageContentQuery`: `data.user` (null user gives a null
  /// profile) and the viewer id from `data.viewer.user.id`.
  (UserProfile?, String?) graphqlProfile(Node body) {
    final data = body['data'];
    if (!data.has('user')) throw SchemaException(data['user'].path);
    final viewer = data['viewer']['user']['id'].stringOrNull;
    final user = data['user'];
    return (user.isNull ? null : users.profile(user), viewer);
  }

  /// `PolarisStoriesV3ReelPageStandaloneQuery`:
  /// `data.xdt_api__v1__feed__reels_media.reels_media[]`.
  Map<String, StoryReel> graphqlStories(Node body) {
    final root = body['data']['xdt_api__v1__feed__reels_media'];
    return _reels(root['reels_media'].list);
  }

  /// `PolarisProfilePostsQuery`:
  /// `data.xdt_api__v1__feed__user_timeline_graphql_connection.edges[].node`
  /// and the viewer id from `data.xdt_viewer.user.id`.
  Timeline graphqlTimeline(Node body, {String? usernameUsed}) {
    final data = body['data'];
    final connection =
        data['xdt_api__v1__feed__user_timeline_graphql_connection'];
    final edges = connection['edges'].list;
    final info = connection['page_info'];
    final cursor = info['end_cursor'].stringOrNull;
    return _timeline(
      [for (final e in edges) e['node']],
      viewerId: data['xdt_viewer']['user']['id'].stringOrNull,
      usernameUsed: usernameUsed,
      endCursor: cursor == null || cursor.isEmpty ? null : cursor,
      hasNextPage: info['has_next_page'].boolOrNull,
    );
  }

  /// The highlights tray: `data.highlights.edges[].node` (**unverified
  /// shape**, see INSTAGRAM_EXTRACTION v0.3). Order is the tray order. A node
  /// without an `id` is skipped; the tray fails only when every node is
  /// malformed.
  List<RemoteHighlight> graphqlHighlights(Node body) {
    final edges = body['data']['highlights']['edges'].list;
    final out = <RemoteHighlight>[];
    SchemaException? first;
    for (final edge in edges) {
      final node = edge['node'];
      try {
        final id = stripHighlightPrefix(node['id'].string);
        if (id.isEmpty) throw SchemaException(node['id'].path);
        out.add(
          RemoteHighlight(
            id: id,
            title: node['title'].stringOrNull ?? '',
            coverUrl: node['cover_media']['cropped_image_version']['url']
                .stringOrNull,
            itemCount: node['media_count'].intOrNull,
            latestItemAt: node['latest_reel_media'].unixTimeOrNull,
          ),
        );
      } on SchemaException catch (e) {
        first ??= e;
      }
    }
    if (out.isEmpty && first != null) throw first;
    return out;
  }

  /// The items of highlight reels from the stories reel query. Reels carry
  /// `id` = `highlight:<id>`. Only the [requested] ids are read; the map is
  /// keyed by the plain id and ordered by `postedAt`, oldest first. The
  /// `order` extra is the position in [requested] (the caller may overwrite).
  Map<String, List<RemoteContent>> graphqlHighlightItems(
    Node body,
    List<String> requested,
  ) {
    final root = body['data']['xdt_api__v1__feed__reels_media'];
    final out = <String, List<RemoteContent>>{};
    for (final reel in root['reels_media'].list) {
      final id = stripHighlightPrefix(reel['id'].string);
      final order = requested.indexOf(id);
      if (order < 0) continue;
      final title = reel['title'].stringOrNull;
      out[id] = [
        for (final item in reel['items'].listOrEmpty)
          ?media.highlight(item, highlightId: id, title: title, order: order),
      ]..sort((a, b) => a.postedAt.compareTo(b.postedAt));
    }
    return out;
  }

  // ---------------------------------------------------------------- REST

  /// IG-1 `web_profile_info`: `data.user`. Null user gives null.
  UserProfile? restWebProfile(Node body) {
    final data = body['data'];
    if (!data.has('user')) throw SchemaException(data['user'].path);
    final user = data['user'];
    return user.isNull ? null : users.profile(user);
  }

  /// IG-3 `users/{id}/info`: `user`.
  UserProfile restUserInfo(Node body) => users.profile(_required(body['user']));

  /// IG-4 `current_user`: `user.pk`.
  Viewer restCurrentUser(Node body) {
    final user = _required(body['user']);
    final profile = users.profile(user);
    return Viewer(viewerId: profile.user.remoteUserId, profile: profile);
  }

  /// IG-2 `reels_media`: `reels` (an object keyed by user id) or
  /// `reels_media[]`.
  Map<String, StoryReel> restReels(Node body) {
    final reels = body['reels'];
    if (!reels.isNull) {
      final map = reels.map;
      return _reels([
        for (final key in map.keys) Node(map[key], '${reels.path}.<id>'),
      ]);
    }
    return _reels(body['reels_media'].list);
  }

  /// IG-5 `feed/user/{id}`: `items[]`.
  Timeline restFeed(Node body) => _timeline(body['items'].list);

  // -------------------------------------------------------------- shared

  /// Reads the fields change detection needs from a media object. `pk` and
  /// `taken_at` are required; the pinned and co-author lists are read
  /// tolerantly (a wrong type counts as empty).
  TimelineEntry entry(Node node) {
    final raw = node.value;
    final map = raw is Map<String, Object?> ? raw : const <String, Object?>{};
    final pinned = map['timeline_pinned_user_ids'];
    final coauthors = map['coauthor_producers'];
    return TimelineEntry(
      node: node,
      pk: node['pk'].string,
      takenAt: node['taken_at'].unixTime,
      pinned: pinned is List<Object?> && pinned.isNotEmpty,
      authorIds: {?_pkOf(map['user']), ?_pkOf(map['owner_id'])},
      coauthorIds: {
        if (coauthors is List<Object?>)
          for (final c in coauthors) ?_pkOf(c),
      },
    );
  }

  static String? _pkOf(Object? user) {
    if (user is! Map<String, Object?>) return null;
    final pk = user['pk'];
    final text = pk is String ? pk : (pk is int ? pk.toString() : null);
    return text == null || text.isEmpty ? null : text;
  }

  /// Maps edges to entries. A malformed edge is skipped and counted; the
  /// page fails (with the first problem) only when every edge is malformed.
  Timeline _timeline(
    List<Node> nodes, {
    String? viewerId,
    String? usernameUsed,
    String? endCursor,
    bool? hasNextPage,
  }) {
    final entries = <TimelineEntry>[];
    SchemaException? first;
    var skipped = 0;
    for (final node in nodes) {
      try {
        entries.add(entry(node));
      } on SchemaException catch (e) {
        skipped++;
        first ??= e;
      }
    }
    if (entries.isEmpty && first != null) throw first;
    return Timeline(
      entries: entries,
      viewerId: viewerId,
      usernameUsed: usernameUsed,
      skippedMalformed: skipped,
      endCursor: endCursor,
      hasNextPage: hasNextPage,
    );
  }

  Map<String, StoryReel> _reels(List<Node> reels) {
    final out = <String, StoryReel>{};
    for (final reel in reels) {
      final type = reel['reel_type'].stringOrNull;
      if (type != null && type != 'user_reel') continue;
      final userId = reel['id'].stringOrNull ?? reel['user']['pk'].string;
      final items = <RemoteContent>[
        for (final item in reel['items'].listOrEmpty) ?media.story(item),
      ]..sort((a, b) => a.postedAt.compareTo(b.postedAt));
      out[userId] = StoryReel(
        userId: userId,
        latestReelMedia: reel['latest_reel_media'].unixTimeOrNull,
        items: items,
      );
    }
    return out;
  }

  Node _required(Node node) {
    if (node.isNull) throw SchemaException(node.path);
    return node;
  }
}
