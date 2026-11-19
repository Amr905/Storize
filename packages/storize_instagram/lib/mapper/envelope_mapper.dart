import 'package:storize_instagram/mapper/media_mapper.dart';
import 'package:storize_instagram/mapper/node.dart';
import 'package:storize_instagram/mapper/user_mapper.dart';
import 'package:storize_model/storize_model.dart';

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

  /// Whether the profile owner pinned it (`timeline_pinned_user_ids`).
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
  const Timeline({required this.entries, this.viewerId, this.usernameUsed});

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
    final edges =
        data['xdt_api__v1__feed__user_timeline_graphql_connection']['edges']
            .list;
    return Timeline(
      entries: [for (final e in edges) entry(e['node'])],
      viewerId: data['xdt_viewer']['user']['id'].stringOrNull,
      usernameUsed: usernameUsed,
    );
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
  Timeline restFeed(Node body) => Timeline(
    entries: [for (final n in body['items'].list) entry(n)],
  );

  // -------------------------------------------------------------- shared

  /// Reads the fields change detection needs from a media object.
  TimelineEntry entry(Node node) {
    final authors = <String>{
      ?node['user']['pk'].stringOrNull,
      ?node['owner_id']['pk'].stringOrNull,
    };
    final coauthors = <String>{
      for (final c in node['coauthor_producers'].listOrEmpty)
        ?c['pk'].stringOrNull,
    };
    return TimelineEntry(
      node: node,
      pk: node['pk'].string,
      takenAt: node['taken_at'].unixTime,
      pinned: node['timeline_pinned_user_ids'].listOrEmpty.isNotEmpty,
      authorIds: authors,
      coauthorIds: coauthors,
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
