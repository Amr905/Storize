import 'package:flutter/foundation.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The date presets of S-05.
enum DatePreset { any, today, days7, days30, custom }

/// The type options of S-05. Carousels and reels apply to posts only.
enum TypeFilter { all, photos, videos, carousels, reels }

/// The filters of S-05 except the kind (which is the S-04 switch).
@immutable
class LibraryFilters {
  /// Creates filters. [targetIds] is copied.
  LibraryFilters({
    Set<int> targetIds = const {},
    this.date = DatePreset.any,
    this.customFrom,
    this.customTo,
    this.type = TypeFilter.all,
    this.highlightsOnly = false,
  }) : targetIds = Set<int>.unmodifiable(targetIds);

  /// No filters.
  static final LibraryFilters none = LibraryFilters();

  /// Only these targets; empty means all.
  final Set<int> targetIds;

  /// The date preset.
  final DatePreset date;

  /// First day of a custom range (a date; the time is ignored).
  final DateTime? customFrom;

  /// Last day of a custom range, inclusive.
  final DateTime? customTo;

  /// Photo, video, carousel or reel.
  final TypeFilter type;

  /// Only highlight items (FR-72). They are stories in the kind switch.
  final bool highlightsOnly;

  /// Whether anything narrows the library (the kind is not counted).
  bool get isActive =>
      targetIds.isNotEmpty ||
      date != DatePreset.any ||
      type != TypeFilter.all ||
      highlightsOnly;

  /// The type that applies to [kind]: carousels and reels mean nothing for
  /// stories.
  TypeFilter effectiveType(LibraryKind kind) =>
      kind == LibraryKind.stories &&
          (type == TypeFilter.carousels || type == TypeFilter.reels)
      ? TypeFilter.all
      : type;

  /// Returns a copy with the given fields replaced.
  LibraryFilters copyWith({
    Set<int>? targetIds,
    DatePreset? date,
    DateTime? customFrom,
    DateTime? customTo,
    TypeFilter? type,
    bool? highlightsOnly,
  }) => LibraryFilters(
    targetIds: targetIds ?? this.targetIds,
    date: date ?? this.date,
    customFrom: customFrom ?? this.customFrom,
    customTo: customTo ?? this.customTo,
    type: type ?? this.type,
    highlightsOnly: highlightsOnly ?? this.highlightsOnly,
  );

  /// The repo filter for [kind] at [now] (UTC). Local midnights bound the
  /// date presets.
  ContentFilter toContentFilter(LibraryKind kind, DateTime now) {
    final local = now.toLocal();
    final midnight = DateTime(local.year, local.month, local.day);
    DateTime? from;
    DateTime? to;
    switch (date) {
      case DatePreset.any:
        break;
      case DatePreset.today:
        from = midnight.toUtc();
      case DatePreset.days7:
        from = DateTime(
          midnight.year,
          midnight.month,
          midnight.day - 6,
        ).toUtc();
      case DatePreset.days30:
        from = DateTime(
          midnight.year,
          midnight.month,
          midnight.day - 29,
        ).toUtc();
      case DatePreset.custom:
        final a = customFrom;
        final b = customTo;
        if (a != null) from = DateTime(a.year, a.month, a.day).toUtc();
        if (b != null) to = DateTime(b.year, b.month, b.day + 1).toUtc();
    }
    final t = effectiveType(kind);
    return ContentFilter(
      kind: highlightsOnly
          ? ContentKind.highlight
          : kind == LibraryKind.stories
          ? ContentKind.story
          : ContentKind.post,
      targetIds: targetIds,
      from: from,
      to: to,
      mediaType: switch (t) {
        TypeFilter.photos => MediaType.photo,
        TypeFilter.videos => MediaType.video,
        _ => null,
      },
    );
  }

  /// Whether [item] passes the post-shape part of the type filter, which the
  /// repo filter cannot express.
  bool matchesShape(ContentWithMedia item, LibraryKind kind) =>
      switch (effectiveType(kind)) {
        TypeFilter.carousels => item.content.postType == PostType.carousel,
        TypeFilter.reels => item.content.postType == PostType.reel,
        _ => true,
      };

  @override
  bool operator ==(Object other) =>
      other is LibraryFilters &&
      setEquals(other.targetIds, targetIds) &&
      other.date == date &&
      other.customFrom == customFrom &&
      other.customTo == customTo &&
      other.type == type &&
      other.highlightsOnly == highlightsOnly;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(targetIds),
    date,
    customFrom,
    customTo,
    type,
    highlightsOnly,
  );
}
