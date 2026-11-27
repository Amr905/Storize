import 'package:storize_model/src/internal/db_enum.dart';

/// Why a session is not usable.
enum SessionReason {
  /// The session cookies were rejected; the user must log in again.
  loginRequired,

  /// Instagram asked for a checkpoint or challenge.
  challenge,
}

/// Remote platforms. The MVP ships only Instagram.
enum PlatformId implements DbEnum {
  /// Instagram.
  instagram('INSTAGRAM');

  const PlatformId(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static PlatformId fromDb(String value) => decodeDbEnum(values, value);
}

/// Kinds of remote content.
enum ContentKind implements DbEnum {
  /// A 24-hour story.
  story('STORY'),

  /// A feed post, reel or carousel.
  post('POST'),

  /// A story saved in a highlight (FR-71). Stored like a story, plus
  /// `highlightId`, `highlightTitle` and `highlightOrder` in `extras`.
  highlight('HIGHLIGHT');

  const ContentKind(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static ContentKind fromDb(String value) => decodeDbEnum(values, value);
}

/// How far back the post history of a target reaches (FR-68).
enum HistoryRange implements DbEnum {
  /// No history: only new posts.
  none('NONE'),

  /// Posts since the start of today (device local time).
  today('TODAY'),

  /// Posts of the last 7 days.
  days7('DAYS_7'),

  /// Posts of the last 30 days.
  days30('DAYS_30'),

  /// Posts since a chosen date (`historySince`).
  since('SINCE'),

  /// Every post.
  all('ALL');

  const HistoryRange(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static HistoryRange fromDb(String value) => decodeDbEnum(values, value);
}

/// State of a post-history backfill (FR-69).
enum HistoryState implements DbEnum {
  /// Nothing to do.
  idle('IDLE'),

  /// Fetching pages, one per background run.
  running('RUNNING'),

  /// Paused by the user.
  paused('PAUSED'),

  /// The range was reached or the posts ran out.
  done('DONE'),

  /// Stopped for a reason that needs the user.
  failed('FAILED');

  const HistoryState(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static HistoryState fromDb(String value) => decodeDbEnum(values, value);
}

/// Post shapes, as Instagram reports them (`post_type` in the database).
enum PostType implements DbEnum {
  /// A single photo.
  photo('PHOTO'),

  /// A single video.
  video('VIDEO'),

  /// Several slides.
  carousel('CAROUSEL'),

  /// A reel (a video with the `clips` product type).
  reel('REEL');

  const PostType(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static PostType fromDb(String value) => decodeDbEnum(values, value);
}

/// The kind of a single media file.
enum MediaType implements DbEnum {
  /// An image file.
  photo('PHOTO'),

  /// A video file.
  video('VIDEO');

  const MediaType(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static MediaType fromDb(String value) => decodeDbEnum(values, value);
}

/// Consent category of a tracked target (BR-1).
enum TargetCategory implements DbEnum {
  /// An account the user owns.
  ownClient('OWN_CLIENT'),

  /// An account whose owner consented.
  consented('CONSENTED'),

  /// A public account.
  public('PUBLIC');

  const TargetCategory(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static TargetCategory fromDb(String value) => decodeDbEnum(values, value);
}

/// Health of a tracked target.
enum TargetStatus implements DbEnum {
  /// Checked normally.
  active('ACTIVE'),

  /// Paused by the user.
  paused('PAUSED'),

  /// Exists but cannot be seen right now.
  notVisible('NOT_VISIBLE'),

  /// The account no longer exists.
  unavailable('UNAVAILABLE'),

  /// The last check failed for another reason.
  error('ERROR'),

  /// Added while Instagram was limited or unreachable: the profile lookup
  /// is still to do (FR-73). Checks, history and highlights skip it.
  pendingLookup('PENDING_LOOKUP');

  const TargetStatus(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static TargetStatus fromDb(String value) => decodeDbEnum(values, value);
}

/// Health of the logged-in account.
enum AccountStatus implements DbEnum {
  /// The session works.
  active('ACTIVE'),

  /// The user must log in again.
  needsRelogin('NEEDS_RELOGIN'),

  /// Instagram restricted the account.
  restricted('RESTRICTED'),

  /// The session was cleared or could not be read.
  loggedOut('LOGGED_OUT');

  const AccountStatus(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static AccountStatus fromDb(String value) => decodeDbEnum(values, value);
}

/// Download progress of a content row.
enum ContentStatus implements DbEnum {
  /// Waiting for its media.
  pending('PENDING'),

  /// Some slides are downloaded and some failed (EC-21).
  partial('PARTIAL'),

  /// All media is downloaded.
  done('DONE'),

  /// Gone from Instagram before it could be downloaded (EC-7).
  removedBeforeDownload('REMOVED_BEFORE_DOWNLOAD');

  const ContentStatus(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static ContentStatus fromDb(String value) => decodeDbEnum(values, value);
}

/// Download progress of a single media file.
enum MediaFileStatus implements DbEnum {
  /// Waiting to be downloaded.
  pending('PENDING'),

  /// Being streamed right now.
  downloading('DOWNLOADING'),

  /// Saved to the gallery.
  done('DONE'),

  /// Failed after the maximum attempts.
  failed('FAILED'),

  /// The gallery file was deleted outside the app (EC-20).
  fileMissing('FILE_MISSING');

  const MediaFileStatus(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static MediaFileStatus fromDb(String value) => decodeDbEnum(values, value);
}

/// Which content a check run looks at.
///
/// [all] has no `check_run.scope` value in TECH_SPEC §3, because that column
/// only holds STORIES or POSTS. Its `ALL` value lets Dart callers ask for both
/// scopes at once.
enum CheckScope implements DbEnum {
  /// Stories only.
  stories('STORIES'),

  /// Posts only.
  posts('POSTS'),

  /// Stories and posts.
  all('ALL');

  const CheckScope(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static CheckScope fromDb(String value) => decodeDbEnum(values, value);
}

/// What started a check run.
enum CheckTrigger implements DbEnum {
  /// The background schedule.
  periodic('PERIODIC'),

  /// "Check now" for all targets.
  manualAll('MANUAL_ALL'),

  /// "Check now" for one target.
  manualOne('MANUAL_ONE'),

  /// The first check after a target was added.
  firstCheck('FIRST_CHECK');

  const CheckTrigger(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static CheckTrigger fromDb(String value) => decodeDbEnum(values, value);
}

/// Outcome of a check run.
enum CheckResult implements DbEnum {
  /// Every target was checked.
  ok('OK'),

  /// Some targets failed or the budget ran out.
  partial('PARTIAL'),

  /// Not run because the session is not active (BR-7).
  skippedSession('SKIPPED_SESSION'),

  /// Stopped by a rate limit.
  rateLimited('RATE_LIMITED'),

  /// Failed as a whole.
  failed('FAILED');

  const CheckResult(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static CheckResult fromDb(String value) => decodeDbEnum(values, value);
}

/// How a check obtained its data.
enum ExtractionMode implements DbEnum {
  /// Direct JSON requests (the normal path).
  direct('DIRECT'),

  /// Headless WebView fallback.
  page('PAGE');

  const ExtractionMode(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static ExtractionMode fromDb(String value) => decodeDbEnum(values, value);
}

/// Which extraction modes a call may use. Dart-only: never stored.
enum ExtractionPolicy {
  /// Direct mode only.
  directOnly,

  /// Direct mode, then page mode if the schema changed.
  directThenPage,
}

/// Types of user-visible activity events (TECH_SPEC §3 `activity_event`).
enum ActivityType implements DbEnum {
  /// A check finished.
  checkDone('CHECK_DONE'),

  /// Stories were downloaded.
  downloadedStories('DOWNLOADED_STORIES'),

  /// Posts were downloaded.
  downloadedPosts('DOWNLOADED_POSTS'),

  /// Content vanished before it could be downloaded.
  removedBeforeDownload('REMOVED_BEFORE_DOWNLOAD'),

  /// A gap in story checks was detected.
  gap('GAP'),

  /// Instagram rate-limited us.
  rateLimited('RATE_LIMITED'),

  /// The session needs attention.
  sessionProblem('SESSION_PROBLEM'),

  /// Instagram's responses changed.
  platformChanged('PLATFORM_CHANGED'),

  /// Page mode was used for a run.
  pageModeUsed('PAGE_MODE_USED'),

  /// Free space is low.
  storageLow('STORAGE_LOW'),

  /// Downloads are paused for lack of space.
  storagePaused('STORAGE_PAUSED'),

  /// A target's status changed.
  targetStatus('TARGET_STATUS'),

  /// A gallery file is missing.
  fileMissing('FILE_MISSING'),

  /// The app crashed on a previous run.
  appCrash('APP_CRASH');

  const ActivityType(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static ActivityType fromDb(String value) => decodeDbEnum(values, value);
}

/// Severity of an activity event. The DB values follow the SCREAMING_SNAKE
/// convention; TECH_SPEC §3 does not list them, so they are a proposal.
enum Severity implements DbEnum {
  /// Informational.
  info('INFO'),

  /// Needs attention.
  warn('WARN'),

  /// A failure.
  error('ERROR');

  const Severity(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static Severity fromDb(String value) => decodeDbEnum(values, value);
}

/// Outcome of the last check of one target (`target.last_check_outcome`, FR-75).
enum TargetCheckOutcome implements DbEnum {
  /// The check saved new items.
  ok('OK'),

  /// The check worked and found nothing new.
  nothingNew('NOTHING_NEW'),

  /// The check failed; the short reason is in `target.last_check_code`.
  failed('FAILED');

  const TargetCheckOutcome(this.dbValue);

  @override
  final String dbValue;

  /// Maps a database value. Throws [ArgumentError] if unknown.
  static TargetCheckOutcome fromDb(String value) => decodeDbEnum(values, value);
}
