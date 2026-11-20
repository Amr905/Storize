import 'package:flutter/foundation.dart';
import 'package:storize_domain/storize_domain.dart';

/// One row of the library list, built lazily by the page.
@immutable
sealed class LibraryRow {
  const LibraryRow();
}

/// The "@account . N" sub-header of a day.
final class AccountHeaderRow extends LibraryRow {
  /// Creates a header.
  const AccountHeaderRow({
    required this.target,
    required this.count,
    required this.newCount,
  });

  /// The account, or null when it is unknown.
  final Target? target;

  /// Items of this account on this day.
  final int count;

  /// Unviewed items among them.
  final int newCount;
}

/// Up to three tiles.
final class TilesRow extends LibraryRow {
  /// Creates a row.
  const TilesRow(this.items);

  /// The items, left to right.
  final List<ContentWithMedia> items;
}

/// All items of one local day.
@immutable
class DayGroup {
  /// Creates a group.
  const DayGroup({required this.day, required this.rows});

  /// The local date (midnight).
  final DateTime day;

  /// Account headers and tile rows, in order.
  final List<LibraryRow> rows;
}

/// Everything the Library page renders, computed once per data change.
@immutable
class LibraryView {
  /// Creates a view.
  const LibraryView({
    required this.groups,
    required this.itemCount,
    required this.targets,
    required this.targetsById,
    required this.unviewedStories,
    required this.unviewedPosts,
    required this.totalOfKind,
    required this.filtersActive,
    required this.now,
    required this.lastCheck,
  });

  /// Day groups, newest first.
  final List<DayGroup> groups;

  /// Items that pass the filters, for the current kind.
  final int itemCount;

  /// All targets, ordered by name.
  final List<Target> targets;

  /// [targets] by ID.
  final Map<int, Target> targetsById;

  /// Unviewed stories (all accounts).
  final int unviewedStories;

  /// Unviewed posts (all accounts).
  final int unviewedPosts;

  /// Items of the current kind before the filters (decides empty (b) vs (c)).
  final int totalOfKind;

  /// Whether filters beyond the kind are on.
  final bool filtersActive;

  /// The clock at build time (UTC).
  final DateTime now;

  /// The newest check time for the current kind, or null.
  final DateTime? lastCheck;

  /// Every item in display order. Used by selection actions.
  Iterable<ContentWithMedia> get items sync* {
    for (final g in groups) {
      for (final r in g.rows) {
        if (r is TilesRow) yield* r.items;
      }
    }
  }
}

/// Number of tiles per row.
const int libraryColumns = 3;

/// Groups [items] (already sorted newest first) by local day, then by account
/// in order of first appearance, and cuts each account into rows of
/// [libraryColumns] tiles.
List<DayGroup> groupLibrary(
  List<ContentWithMedia> items,
  Map<int, Target> targetsById,
) {
  final groups = <DayGroup>[];
  var i = 0;
  while (i < items.length) {
    final local = items[i].content.postedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final byAccount = <int, List<ContentWithMedia>>{};
    while (i < items.length) {
      final l = items[i].content.postedAt.toLocal();
      if (l.year != day.year || l.month != day.month || l.day != day.day) {
        break;
      }
      byAccount.putIfAbsent(items[i].content.targetId, () => []).add(items[i]);
      i++;
    }
    final rows = <LibraryRow>[];
    byAccount.forEach((targetId, list) {
      rows.add(
        AccountHeaderRow(
          target: targetsById[targetId],
          count: list.length,
          newCount: list.where((e) => !e.content.viewed).length,
        ),
      );
      for (var j = 0; j < list.length; j += libraryColumns) {
        final end = j + libraryColumns > list.length
            ? list.length
            : j + libraryColumns;
        rows.add(TilesRow(list.sublist(j, end)));
      }
    });
    groups.add(DayGroup(day: day, rows: rows));
  }
  return groups;
}
