import 'package:drift/drift.dart';
import 'package:storize_data/db/converters.dart';

// Drift tables for schema v1. Column names are snake_case (drift's default
// for camelCase getters); see TECH_SPEC §3. Timestamps are INTEGER epoch ms.
//
// NOT NULL: §3 spells out NOT NULL only for a few columns. Columns that the
// domain entities treat as required (platform, status, kind, posted_at,
// detected_at, flags with defaults, ...) are NOT NULL here as well.

/// `login_account`: the logged-in Instagram account (MVP: one row).
@DataClassName('LoginAccountRow')
class LoginAccounts extends Table {
  @override
  String get tableName => 'login_account';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get platform => text().map(const PlatformIdConverter())();
  TextColumn get remoteUserId => text().unique()();
  TextColumn get username => text()();
  TextColumn get status => text().map(const AccountStatusConverter())();
  TextColumn get statusReason => text().nullable()();
  IntColumn get connectedAt => integer().map(const EpochMsConverter())();
  IntColumn get lastSuccessAt =>
      integer().nullable().map(const EpochMsConverter())();
  TextColumn get userAgent => text().nullable()();
}

/// `target`: a tracked account.
@DataClassName('TargetRow')
@TableIndex(name: 'idx_target_status', columns: {#status})
class Targets extends Table {
  @override
  String get tableName => 'target';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get platform => text().map(const PlatformIdConverter())();
  TextColumn get remoteUserId => text()();
  TextColumn get username => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get category => text().map(const TargetCategoryConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().map(const TargetStatusConverter())();
  TextColumn get statusReason => text().nullable()();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  BoolColumn get trackStories => boolean().withDefault(const Constant(true))();
  BoolColumn get trackPosts => boolean().withDefault(const Constant(true))();
  BoolColumn get trackReels => boolean().withDefault(const Constant(true))();
  IntColumn get postsWatermarkAt => integer().map(const EpochMsConverter())();
  IntColumn get loginAccountId => integer().nullable().references(
    LoginAccounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get addedAt => integer().map(const EpochMsConverter())();
  IntColumn get lastStoriesCheckAt =>
      integer().nullable().map(const EpochMsConverter())();
  IntColumn get lastPostsCheckAt =>
      integer().nullable().map(const EpochMsConverter())();
  IntColumn get lastNewStoryAt =>
      integer().nullable().map(const EpochMsConverter())();
  IntColumn get lastNewPostAt =>
      integer().nullable().map(const EpochMsConverter())();
  // Added in schema v2 (T-040, TECH_SPEC §17).
  TextColumn get historyRange => text()
      .map(const HistoryRangeConverter())
      .withDefault(const Constant('NONE'))();
  IntColumn get historySince =>
      integer().nullable().map(const EpochMsConverter())();
  TextColumn get historyState => text()
      .map(const HistoryStateConverter())
      .withDefault(const Constant('IDLE'))();
  TextColumn get historyCursor => text().nullable()();
  IntColumn get historyFetched => integer().withDefault(const Constant(0))();
  IntColumn get historyOldestSeenAt =>
      integer().nullable().map(const EpochMsConverter())();
  IntColumn get historyUpdatedAt =>
      integer().nullable().map(const EpochMsConverter())();
  BoolColumn get highlightsEnabled =>
      boolean().withDefault(const Constant(false))();
  // Added in schema v4 (T-056, FR-75): what the last check of the target did.
  IntColumn get lastSuccessAt =>
      integer().nullable().map(const EpochMsConverter())();
  TextColumn get lastCheckOutcome =>
      text().nullable().map(const TargetCheckOutcomeConverter())();
  TextColumn get lastCheckCode => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {platform, remoteUserId},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (track_stories + track_posts + track_reels >= 1)',
  ];
}

/// `content`: a story or a post. Stories have exactly one media file.
@DataClassName('ContentRow')
@TableIndex(
  name: 'idx_content_kind_posted_at',
  columns: {
    #kind,
    IndexedColumn(#postedAt, orderBy: OrderingMode.desc),
  },
)
@TableIndex(
  name: 'idx_content_target_kind_posted_at',
  columns: {
    #targetId,
    #kind,
    IndexedColumn(#postedAt, orderBy: OrderingMode.desc),
  },
)
class Contents extends Table {
  @override
  String get tableName => 'content';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get targetId =>
      integer().references(Targets, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text().map(const ContentKindConverter())();
  TextColumn get remoteId => text()();
  TextColumn get shortcode => text().nullable()();
  TextColumn get postType => text().nullable().map(const PostTypeConverter())();
  IntColumn get postedAt => integer().map(const EpochMsConverter())();
  IntColumn get expiresAt =>
      integer().nullable().map(const EpochMsConverter())();
  TextColumn get caption => text().nullable()();
  TextColumn get locationName => text().nullable()();
  TextColumn get taggedUsernames => text().nullable()();
  IntColumn get slideCount => integer().withDefault(const Constant(1))();
  BoolColumn get isCloseFriends =>
      boolean().withDefault(const Constant(false))();
  TextColumn get extrasJson => text().nullable()();
  IntColumn get detectedAt => integer().map(const EpochMsConverter())();
  TextColumn get status => text().map(const ContentStatusConverter())();
  BoolColumn get viewed => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {targetId, kind, remoteId},
  ];
}

/// `media_file`: one downloadable file (a story, or one slide of a post).
@DataClassName('MediaFileRow')
@TableIndex(name: 'idx_media_file_status', columns: {#status})
class MediaFiles extends Table {
  @override
  String get tableName => 'media_file';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get contentId =>
      integer().references(Contents, #id, onDelete: KeyAction.cascade)();
  IntColumn get slideIndex => integer().withDefault(const Constant(0))();
  TextColumn get mediaType => text().map(const MediaTypeConverter())();
  TextColumn get sourceUrl => text()();
  TextColumn get status => text().map(const MediaFileStatusConverter())();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get contentUri => text().nullable()();
  TextColumn get relativePath => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get thumbPath => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get downloadedAt =>
      integer().nullable().map(const EpochMsConverter())();

  @override
  List<Set<Column>> get uniqueKeys => [
    {contentId, slideIndex},
  ];
}

/// `check_run`: one background or manual check.
@DataClassName('CheckRunRow')
@TableIndex(
  name: 'idx_check_run_scope_started_at',
  columns: {#scope, #startedAt},
)
class CheckRuns extends Table {
  @override
  String get tableName => 'check_run';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get scope => text().map(const CheckRunScopeConverter())();
  TextColumn get trigger => text().map(const CheckTriggerConverter())();
  IntColumn get startedAt => integer().map(const EpochMsConverter())();
  IntColumn get finishedAt =>
      integer().nullable().map(const EpochMsConverter())();
  TextColumn get result =>
      text().nullable().map(const CheckResultConverter())();
  TextColumn get mode =>
      text().nullable().map(const ExtractionModeConverter())();
  IntColumn get targetsChecked => integer().withDefault(const Constant(0))();
  IntColumn get newItems => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();

  @override
  List<String> get customConstraints => [
    "CHECK (scope IN ('STORIES', 'POSTS'))",
  ];
}

/// `activity_event`: user-visible activity, pruned after 7 days (FR-52).
@DataClassName('ActivityEventRow')
@TableIndex(
  name: 'idx_activity_event_at',
  columns: {IndexedColumn(#at, orderBy: OrderingMode.desc)},
)
class ActivityEvents extends Table {
  @override
  String get tableName => 'activity_event';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get at => integer().map(const EpochMsConverter())();
  TextColumn get type => text().map(const ActivityTypeConverter())();
  TextColumn get severity => text().map(const SeverityConverter())();
  IntColumn get targetId => integer().nullable().references(
    Targets,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get checkRunId => integer().nullable().references(
    CheckRuns,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get count => integer().withDefault(const Constant(1))();
  TextColumn get payloadJson => text().nullable()();
}

/// `governor_lease`: RequestGovernor state shared between isolates (ADR-9).
///
/// There is no FK to `login_account` in §3, so a lease can be written before
/// the account row exists in tests and survives account removal.
@DataClassName('GovernorLeaseRow')
class GovernorLeases extends Table {
  @override
  String get tableName => 'governor_lease';

  IntColumn get loginAccountId => integer()();
  TextColumn get holder => text()();
  IntColumn get expiresAt => integer().map(const EpochMsConverter())();
  RealColumn get tokens => real()();
  IntColumn get lastRefillAt => integer().map(const EpochMsConverter())();
  IntColumn get backoffUntil =>
      integer().nullable().map(const EpochMsConverter())();
  RealColumn get backoffMultiplier => real().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {loginAccountId};
}
