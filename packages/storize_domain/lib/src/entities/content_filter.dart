import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/content.dart';
import 'package:storize_domain/src/entities/internal.dart';
import 'package:storize_domain/src/entities/media_file.dart';
import 'package:storize_model/storize_model.dart';

/// Which content the library shows (UX S-04). All fields are optional; an
/// empty filter matches everything.
@immutable
final class ContentFilter {
  /// Creates a filter. [targetIds] and [statuses] are copied.
  ContentFilter({
    this.kind,
    Set<int> targetIds = const {},
    this.from,
    this.to,
    this.mediaType,
    Set<ContentStatus> statuses = const {},
  }) : targetIds = Set<int>.unmodifiable(targetIds),
       statuses = Set<ContentStatus>.unmodifiable(statuses);

  /// Only stories or only posts, or both when null.
  final ContentKind? kind;

  /// Only these targets. Empty means all targets.
  final Set<int> targetIds;

  /// Only content posted at or after this instant (inclusive), or null.
  final DateTime? from;

  /// Only content posted before this instant (exclusive), or null.
  final DateTime? to;

  /// Only content with at least one media file of this type, or null.
  final MediaType? mediaType;

  /// Only content with one of these statuses. Empty means any status.
  final Set<ContentStatus> statuses;

  /// Whether [content] (with its [media] files) passes the filter.
  ///
  /// Implementations may run the same rules in SQL; fakes call this.
  bool matches(Content content, List<MediaFile> media) {
    if (kind != null && content.kind != kind) return false;
    if (targetIds.isNotEmpty && !targetIds.contains(content.targetId)) {
      return false;
    }
    if (from != null && content.postedAt.isBefore(from!)) return false;
    if (to != null && !content.postedAt.isBefore(to!)) return false;
    final wanted = mediaType;
    if (wanted != null && !media.any((m) => m.mediaType == wanted)) {
      return false;
    }
    if (statuses.isNotEmpty && !statuses.contains(content.status)) return false;
    return true;
  }

  /// Returns a copy with the given fields replaced. Pass null to clear a
  /// nullable field.
  ContentFilter copyWith({
    Object? kind = unset,
    Set<int>? targetIds,
    Object? from = unset,
    Object? to = unset,
    Object? mediaType = unset,
    Set<ContentStatus>? statuses,
  }) => ContentFilter(
    kind: pick<ContentKind>(kind, this.kind),
    targetIds: targetIds ?? this.targetIds,
    from: pick<DateTime>(from, this.from),
    to: pick<DateTime>(to, this.to),
    mediaType: pick<MediaType>(mediaType, this.mediaType),
    statuses: statuses ?? this.statuses,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentFilter &&
          other.kind == kind &&
          _setEquals(other.targetIds, targetIds) &&
          other.from == from &&
          other.to == to &&
          other.mediaType == mediaType &&
          _setEquals(other.statuses, statuses));

  @override
  int get hashCode => Object.hash(
    kind,
    Object.hashAllUnordered(targetIds),
    from,
    to,
    mediaType,
    Object.hashAllUnordered(statuses),
  );

  @override
  String toString() =>
      'ContentFilter(kind: ${kind?.name}, targetIds: $targetIds, from: $from, '
      'to: $to, mediaType: ${mediaType?.name}, statuses: $statuses)';
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.every(b.contains);
