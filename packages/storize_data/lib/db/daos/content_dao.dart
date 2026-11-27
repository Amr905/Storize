import 'package:drift/drift.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/db/tables.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

part 'content_dao.g.dart';

/// A content row with its media rows (ordered by slide index).
final class ContentWithMediaRows {
  const ContentWithMediaRows(this.content, this.media);

  final ContentRow content;
  final List<MediaFileRow> media;
}

/// A pending media row with its content row.
final class PendingMediaRows {
  const PendingMediaRows(this.file, this.content);

  final MediaFileRow file;
  final ContentRow content;
}

/// Escapes the `LIKE` wildcards `%` and `_` and the escape character itself,
/// for use with `ESCAPE '\\'`.
String escapeLikePattern(String raw) =>
    raw.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

/// `column LIKE pattern ESCAPE '\'`. Drift's `like` has no ESCAPE clause, so
/// this writes the SQL itself. The pattern goes in as a bound variable.
final class _EscapedLike extends Expression<bool> {
  const _EscapedLike(this.column, this.pattern);

  final Expression<String> column;
  final String pattern;

  @override
  Precedence get precedence => Precedence.primary;

  @override
  void writeInto(GenerationContext context) {
    context.buffer.write('(');
    column.writeInto(context);
    context.buffer.write(' LIKE ');
    Variable<String>(pattern).writeInto(context);
    context.buffer.write(r" ESCAPE '\')");
  }
}

/// The highlight title stored in `extras_json`, or NULL when there is none or
/// the JSON is not valid.
final class _HighlightTitle extends Expression<String> {
  const _HighlightTitle(this.json);

  final Expression<String> json;

  @override
  Precedence get precedence => Precedence.primary;

  @override
  void writeInto(GenerationContext context) {
    context.buffer.write('(CASE WHEN json_valid(');
    json.writeInto(context);
    context.buffer.write(') THEN json_extract(');
    json.writeInto(context);
    context.buffer.write(r", '$.highlightTitle') END)");
  }
}

/// Raw queries for `content` and `media_file`.
///
/// Rows come back as drift row classes; T-006 maps them to domain entities.
@DriftAccessor(tables: [Contents, MediaFiles, Targets])
class ContentDao extends DatabaseAccessor<StorizeDatabase>
    with _$ContentDaoMixin {
  ContentDao(super.attachedDatabase);

  // ---- Reads -------------------------------------------------------------

  /// The Library query: content that matches [filter], newest first, joined
  /// with its media (one result row per media file).
  ///
  /// Index use (see the EXPLAIN test): with a `kind` it uses
  /// `idx_content_kind_posted_at`; with `kind` and target ids it uses
  /// `idx_content_target_kind_posted_at`. With neither a kind nor target ids
  /// there is no index on `posted_at` alone, so SQLite scans `content`; the
  /// UI always sets a kind (stories and posts are separate tabs).
  JoinedSelectStatement<HasResultSet, dynamic> libraryQuery(
    ContentFilter filter, {
    String? text,
  }) {
    final query =
        select(contents).join([
            leftOuterJoin(
              mediaFiles,
              mediaFiles.contentId.equalsExp(contents.id),
            ),
          ])
          ..where(
            text == null || text.isEmpty
                ? _libraryPredicate(filter)
                : Expression.and([
                    _libraryPredicate(filter),
                    _textPredicate(text),
                  ]),
          )
          ..orderBy([
            OrderingTerm.desc(contents.postedAt),
            OrderingTerm.desc(contents.id),
            OrderingTerm.asc(mediaFiles.slideIndex),
          ]);
    return query;
  }

  Expression<bool> _libraryPredicate(ContentFilter filter) {
    final kind = filter.kind;
    final from = filter.from;
    final to = filter.to;
    final mediaType = filter.mediaType;
    return Expression.and([
      if (kind != null) contents.kind.equalsValue(kind),
      if (filter.targetIds.isNotEmpty) contents.targetId.isIn(filter.targetIds),
      if (from != null)
        contents.postedAt.isBiggerOrEqualValue(from.millisecondsSinceEpoch),
      if (to != null)
        contents.postedAt.isSmallerThanValue(to.millisecondsSinceEpoch),
      if (filter.statuses.isNotEmpty)
        contents.status.isInValues(filter.statuses),
      if (mediaType != null)
        existsQuery(
          select(mediaFiles)..where(
            (m) =>
                m.contentId.equalsExp(contents.id) &
                m.mediaType.equalsValue(mediaType),
          ),
        ),
    ]);
  }

  /// Library rows, newest first. Emits again when `content` or `media_file`
  /// change.
  Stream<List<ContentWithMediaRows>> watchLibrary(ContentFilter filter) =>
      libraryQuery(filter).watch().map(_groupJoined);

  /// Library rows whose username, caption, location or highlight title
  /// contains [text] (see [_textPredicate]). Emits again on change.
  Stream<List<ContentWithMediaRows>> watchSearch(
    ContentFilter filter,
    String text,
  ) => libraryQuery(filter, text: text).watch().map(_groupJoined);

  /// The text part of the search. `LIKE` with `\` as the escape character, so
  /// a `%` or `_` typed by the user matches itself. LIKE is case-insensitive
  /// for ASCII letters (SQLite's default).
  Expression<bool> _textPredicate(String text) {
    final pattern = '%${escapeLikePattern(text)}%';
    return Expression.or([
      existsQuery(
        select(targets)..where(
          (t) =>
              t.id.equalsExp(contents.targetId) &
              _EscapedLike(t.username, pattern),
        ),
      ),
      _EscapedLike(contents.caption, pattern),
      _EscapedLike(contents.locationName, pattern),
      _EscapedLike(_HighlightTitle(contents.extrasJson), pattern),
    ]);
  }

  /// One-shot version of [watchLibrary].
  Future<List<ContentWithMediaRows>> getLibrary(ContentFilter filter) async =>
      _groupJoined(await libraryQuery(filter).get());

  List<ContentWithMediaRows> _groupJoined(List<TypedResult> rows) {
    final order = <int>[];
    final contentById = <int, ContentRow>{};
    final mediaById = <int, List<MediaFileRow>>{};
    for (final row in rows) {
      final content = row.readTable(contents);
      if (!contentById.containsKey(content.id)) {
        order.add(content.id);
        contentById[content.id] = content;
        mediaById[content.id] = [];
      }
      final media = row.readTableOrNull(mediaFiles);
      if (media != null) mediaById[content.id]!.add(media);
    }
    return [
      for (final id in order)
        ContentWithMediaRows(contentById[id]!, mediaById[id]!),
    ];
  }

  Future<List<ContentWithMediaRows>> _attachMedia(
    List<ContentRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final media =
        await (select(mediaFiles)
              ..where((m) => m.contentId.isIn(rows.map((c) => c.id)))
              ..orderBy([(m) => OrderingTerm.asc(m.slideIndex)]))
            .get();
    final byContent = <int, List<MediaFileRow>>{};
    for (final m in media) {
      (byContent[m.contentId] ??= []).add(m);
    }
    return [
      for (final c in rows)
        ContentWithMediaRows(c, byContent[c.id] ?? const []),
    ];
  }

  Future<ContentWithMediaRows?> getById(int id) async {
    final rows = await getByIds([id]);
    return rows.isEmpty ? null : rows.single;
  }

  /// Rows for the ids that exist, in the order of [ids].
  Future<List<ContentWithMediaRows>> getByIds(Iterable<int> ids) async {
    final wanted = ids.toList();
    if (wanted.isEmpty) return const [];
    final rows = await (select(
      contents,
    )..where((c) => c.id.isIn(wanted))).get();
    final byId = {for (final c in rows) c.id: c};
    return _attachMedia([
      for (final id in wanted)
        if (byId[id] case final ContentRow c) c,
    ]);
  }

  /// All content of a target, newest first (uses
  /// `idx_content_target_kind_posted_at` for the target search).
  Future<List<ContentWithMediaRows>> listByTarget(int targetId) async =>
      _attachMedia(
        await (select(contents)
              ..where((c) => c.targetId.equals(targetId))
              ..orderBy([
                (c) => OrderingTerm.desc(c.postedAt),
                (c) => OrderingTerm.desc(c.id),
              ]))
            .get(),
      );

  /// The subset of [remoteIds] already stored for this target and kind
  /// (uses the UNIQUE `(target_id, kind, remote_id)` index).
  Future<Set<String>> existingRemoteIds(
    int targetId,
    ContentKind kind,
    Iterable<String> remoteIds,
  ) async {
    final wanted = remoteIds.toSet();
    if (wanted.isEmpty) return {};
    final rows =
        await (select(contents)..where(
              (c) =>
                  c.targetId.equals(targetId) &
                  c.kind.equalsValue(kind) &
                  c.remoteId.isIn(wanted),
            ))
            .get();
    return {for (final c in rows) c.remoteId};
  }

  /// Media waiting for download, stories before posts, then oldest detected
  /// first, then content id and slide index. Uses `idx_media_file_status`.
  JoinedSelectStatement<HasResultSet, dynamic> pendingMediaQuery({int? limit}) {
    final query =
        select(mediaFiles).join([
            innerJoin(contents, contents.id.equalsExp(mediaFiles.contentId)),
          ])
          ..where(mediaFiles.status.equalsValue(MediaFileStatus.pending))
          ..orderBy([
            // true (a story) sorts first when descending.
            OrderingTerm.desc(contents.kind.equalsValue(ContentKind.story)),
            OrderingTerm.asc(contents.detectedAt),
            OrderingTerm.asc(contents.id),
            OrderingTerm.asc(mediaFiles.slideIndex),
          ]);
    if (limit != null) query.limit(limit);
    return query;
  }

  Future<List<PendingMediaRows>> pendingMedia({int? limit}) async {
    final rows = await pendingMediaQuery(limit: limit).get();
    return [
      for (final r in rows)
        PendingMediaRows(r.readTable(mediaFiles), r.readTable(contents)),
    ];
  }

  /// Content posted strictly before [cutoff], oldest first.
  Future<List<ContentWithMediaRows>> olderThan(DateTime cutoff) async =>
      _attachMedia(
        await (select(contents)
              ..where(
                (c) => c.postedAt.isSmallerThanValue(
                  cutoff.millisecondsSinceEpoch,
                ),
              )
              ..orderBy([
                (c) => OrderingTerm.asc(c.postedAt),
                (c) => OrderingTerm.asc(c.id),
              ]))
            .get(),
      );

  /// Sum of `size_bytes` of DONE media files, per target id. Targets with no
  /// downloaded bytes are absent.
  Future<Map<int, int>> storageBytesByTarget() async {
    final total = mediaFiles.sizeBytes.sum();
    final query =
        selectOnly(mediaFiles).join([
            innerJoin(contents, contents.id.equalsExp(mediaFiles.contentId)),
          ])
          ..addColumns([contents.targetId, total])
          ..where(
            mediaFiles.status.equalsValue(MediaFileStatus.done) &
                mediaFiles.sizeBytes.isNotNull(),
          )
          ..groupBy([contents.targetId]);
    final rows = await query.get();
    return {for (final r in rows) r.read(contents.targetId)!: r.read(total)!};
  }

  // ---- Writes ------------------------------------------------------------

  /// Inserts [content] and its [media] in one transaction, unless a row with
  /// the same `(target_id, kind, remote_id)` exists (BR-3). The `content_id`
  /// of each media companion is overwritten here (pass 0).
  ///
  /// If any insert fails (for example a duplicate slide index), nothing is
  /// written and the exception propagates.
  Future<({int contentId, bool isNew})> insertIfNew(
    ContentsCompanion content,
    List<MediaFilesCompanion> media,
  ) => transaction(() async {
    final existing =
        await (select(contents)..where(
              (c) =>
                  c.targetId.equals(content.targetId.value) &
                  c.kind.equalsValue(content.kind.value) &
                  c.remoteId.equals(content.remoteId.value),
            ))
            .getSingleOrNull();
    if (existing != null) return (contentId: existing.id, isNew: false);
    final contentId = await into(contents).insert(content);
    for (final file in media) {
      await into(mediaFiles).insert(file.copyWith(contentId: Value(contentId)));
    }
    return (contentId: contentId, isNew: true);
  });

  /// Writes every column of [file] (full replace by id). Returns rows changed.
  Future<int> updateMediaFile(MediaFileRow file) =>
      (update(mediaFiles)..where((m) => m.id.equals(file.id))).write(
        file.toCompanion(false),
      );

  /// Writes only the present fields of [changes]. Returns rows changed.
  Future<int> updateMediaFilePartial(int id, MediaFilesCompanion changes) =>
      (update(mediaFiles)..where((m) => m.id.equals(id))).write(changes);

  /// Writes every column of [content] (full replace by id).
  Future<int> updateContent(ContentRow content) =>
      (update(contents)..where((c) => c.id.equals(content.id))).write(
        content.toCompanion(false),
      );

  /// Writes only the present fields of [changes]. Returns rows changed.
  Future<int> updateContentPartial(int id, ContentsCompanion changes) =>
      (update(contents)..where((c) => c.id.equals(id))).write(changes);

  /// Moves every DOWNLOADING media file back to PENDING (a download was cut
  /// short by a crash or kill). Returns how many were reset.
  Future<int> resetInterruptedDownloads() =>
      (update(mediaFiles)..where(
            (m) => m.status.equalsValue(MediaFileStatus.downloading),
          ))
          .write(
            const MediaFilesCompanion(
              status: Value(MediaFileStatus.pending),
            ),
          );

  /// Marks the given content as viewed.
  Future<void> markViewed(Iterable<int> contentIds) async {
    final ids = contentIds.toList();
    if (ids.isEmpty) return;
    await (update(contents)
          ..where((c) => c.id.isIn(ids) & c.viewed.equals(false)))
        .write(const ContentsCompanion(viewed: Value(true)));
  }

  /// Deletes one media row, and its content row when it was the last one.
  Future<void> deleteMediaFile(int mediaFileId) => transaction(() async {
    final row = await (select(
      mediaFiles,
    )..where((m) => m.id.equals(mediaFileId))).getSingleOrNull();
    if (row == null) return;
    await (delete(mediaFiles)..where((m) => m.id.equals(mediaFileId))).go();
    final left =
        await (select(mediaFiles)
              ..where((m) => m.contentId.equals(row.contentId))
              ..limit(1))
            .get();
    if (left.isEmpty) {
      await (delete(contents)..where((c) => c.id.equals(row.contentId))).go();
    }
  });

  /// Deletes content rows; their media rows cascade. Returns rows deleted.
  Future<int> deleteByIds(Iterable<int> ids) async {
    final wanted = ids.toList();
    if (wanted.isEmpty) return 0;
    return (delete(contents)..where((c) => c.id.isIn(wanted))).go();
  }
}
