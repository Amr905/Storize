import 'dart:async';
import 'dart:typed_data';

import 'package:storize_app/core/composition_platform.dart';
import 'package:storize_app/features/lock/biometric_auth.dart';
import 'package:storize_app/features/onboarding/login_lease.dart';
import 'package:storize_app/features/onboarding/setup_ops.dart';
import 'package:storize_app/notifications/notification_service.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/files/display_names.dart';
import 'package:storize_data/log/crash_marker.dart';
import 'package:storize_data/repo/repo.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_data/security/security.dart';
import 'package:storize_data/update/update.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';

/// How long an interactive foreground op may wait for the request budget.
const Duration interactiveMaxWait = Duration(seconds: 8);

/// The parts of the app that touch the platform (database file, Keystore,
/// MediaStore, network, WebView). `AppComposition.assemble` wires everything
/// else from them, so the wiring is tested with fakes and an in-memory
/// database, and production builds the real parts in `composition_production`.
final class CompositionParts {
  /// Creates the parts.
  const CompositionParts({
    required this.db,
    required this.settings,
    required this.sessions,
    required this.gallery,
    required this.cache,
    required this.storage,
    required this.igHttp,
    required this.cdnHttp,
    required this.pageDriver,
    required this.hookSource,
    required this.seenStore,
    required this.log,
    required this.scheduler,
    required this.enqueuer,
    required this.updateChecker,
    required this.currentVersion,
    required this.pins,
    required this.biometric,
    this.crashMarker,
    this.notifications,
    this.setupOps,
    this.findExisting,
    this.fullPhotoReader,
    this.clock = const SystemClock(),
    this.governorConfig = const GovernorConfig(),
    this.closers = const [],
  });

  /// The open database.
  final StorizeDatabase db;

  /// Settings (shared preferences).
  final SettingsRepo settings;

  /// Where session cookies live. Built by the caller because it needs the
  /// account repo for the "unreadable session" callback.
  final SessionStore sessions;

  /// MediaStore access.
  final GalleryStore gallery;

  /// The private `.part` and thumbnail cache.
  final MediaCache cache;

  /// Free space.
  final StorageInfo storage;

  /// Instagram JSON transport.
  final IgHttp igHttp;

  /// CDN transport.
  final CdnHttp cdnHttp;

  /// The WebView driver of page mode.
  final PageDriver pageDriver;

  /// Loads the page-mode hook script (an asset in production).
  final Future<String> Function() hookSource;

  /// The persisted "seen" breaker.
  final SeenBreakerStore seenStore;

  /// The diagnostic log.
  final DiagnosticLog log;

  /// Background registration.
  final Scheduler scheduler;

  /// Download roll-over.
  final DownloadEnqueuer enqueuer;

  /// The GitHub release check.
  final UpdateChecker updateChecker;

  /// The running app version, for [updateChecker].
  final String currentVersion;

  /// The PIN store.
  final PinStore pins;

  /// Biometric authentication.
  final BiometricAuth biometric;

  /// Device operations of onboarding S-03 (null in tests, which override
  /// `setupOpsProvider` themselves).
  final SetupOps? setupOps;

  /// Adopts a gallery file saved just before a kill (null in tests).
  final GalleryFileFinder? findExisting;

  /// Reads a gallery photo for the full-size viewers (null in tests: the
  /// viewers then keep the thumbnail).
  final Future<Uint8List?> Function(String contentUri)? fullPhotoReader;

  /// The crash marker, to report a pending crash after the database opens.
  final CrashMarker? crashMarker;

  /// The notification service (null in tests that do not check it).
  final NotificationService? notifications;

  /// The clock.
  final Clock clock;

  /// Governor tuning (tests make it fast).
  final GovernorConfig governorConfig;

  /// Called by [AppComposition.dispose], in order (closing the database,
  /// the update checker's client).
  final List<Future<void> Function()> closers;
}

/// What [AppComposition.start] did, for tests and the log.
final class StartReport {
  /// Creates a report.
  const StartReport({
    this.crashReported = false,
    this.partsRemoved = 0,
    this.thumbnailsRemoved = 0,
    this.partSweepSkipped = false,
    this.gap,
  });

  /// A pending crash was turned into an `APP_CRASH` event.
  final bool crashReported;

  /// Orphan `.part` files removed.
  final int partsRemoved;

  /// Orphan thumbnails removed.
  final int thumbnailsRemoved;

  /// The `.part` sweep was skipped because a download holds the lease.
  final bool partSweepSkipped;

  /// The gap found at this start, if any.
  final Gap? gap;
}

/// The public `X-IG-App-ID` of instagram.com's own web client (the value the
/// site's JavaScript sends with every API call). Without it the web API
/// answers HTTP 400, seen on device on the first-login session check
/// (2026-11-22). Not a secret: it names the web app, not a user. Kept here,
/// not in `storize_instagram` (its guardrail forbids such literals there).
const instagramWebAppId = '936619743392459';

/// The composition root (TECH_SPEC section 2): every port, repo and use case,
/// wired once per isolate. The foreground isolate and the background isolate
/// each build their own (`background` differs). Each opens its own database
/// connection to the same file (see `StorizeDatabase.open`) and they share
/// the request budget through the lease table.
final class AppComposition {
  AppComposition._({
    required this.background,
    required this.holder,
    required this.parts,
    required this.governor,
    required this.platform,
    required this.loginPlatform,
    required this.loginLease,
    required this.runCheck,
    required this.backfillHistory,
    required this.syncHighlights,
    required this.downloadPending,
    required this.applyRetention,
    required this.detectGaps,
    required this.deleteContent,
    required this.targets,
    required this.content,
    required this.accounts,
    required this.activity,
    required this.checkRuns,
    required this.leases,
  });

  /// Wires everything from [parts].
  ///
  /// [background] is the isolate kind: `false` for the UI isolate (page mode
  /// allowed in the foreground), `true` for a WorkManager isolate (page mode
  /// only when the `pageModeInBackground` setting is on, read at each use).
  /// The governor holder is unique per call, so two isolates never act as one.
  factory AppComposition.assemble(
    CompositionParts parts, {
    required bool background,
    String? holder,
  }) {
    final clock = parts.clock;
    final log = parts.log;
    final db = parts.db;
    final holderId =
        holder ??
        '${background ? 'bg' : 'ui'}-${clock.now().microsecondsSinceEpoch}-'
            '${_seq++}-${Object().hashCode}';

    final targets = DriftTargetRepo(db);
    final content = DriftContentRepo(db);
    final accounts = DriftAccountRepo(db);
    final activity = DriftActivityRepo(db, clock);
    final checkRuns = DriftCheckRunRepo(db);
    final leases = DriftGovernorLeaseRepo(db, clock);

    final governor = RequestGovernor(
      leases: leases,
      clock: clock,
      holder: holderId,
      config: parts.governorConfig,
      log: (message) => log.log(LogLevel.debug, 'governor', message),
    );
    final webViewLease = GovernorWebViewLease(
      repo: leases,
      clock: clock,
      instanceId: holderId,
      log: log,
    );
    final seenGuard = SeenGuard(store: parts.seenStore, log: log);

    Future<String>? hook;
    Future<InstagramPlatform> build(int accountId) async {
      final source = await (hook ??= parts.hookSource());
      return InstagramPlatform.assemble(
        accountId: accountId,
        governor: governor,
        sessions: parts.sessions,
        http: parts.igHttp,
        cdnHttp: parts.cdnHttp,
        pageDriver: parts.pageDriver,
        hookSource: source,
        targets: targets,
        appId: instagramWebAppId,
        log: log,
        // No `activity`: RunCheck writes PAGE_MODE_USED from the signals.
        clock: clock,
        seenGuard: seenGuard,
        webViewLease: webViewLease,
        runsInBackground: background,
        pageModeInBackground: () async =>
            (await parts.settings.get()).pageModeInBackground,
      );
    }

    // Foreground ops the user waits for must not spin while the budget
    // refills (TECH_SPEC 17.3). Background jobs keep waiting.
    final interactiveWait = background ? null : interactiveMaxWait;
    final platform = ActiveAccountPlatform(
      accounts: accounts,
      factory: build,
      interactiveMaxWait: interactiveWait,
    );
    // S-02 verifies a new session under the staging id before it belongs to
    // any account (never the active account's session).
    final loginPlatform = ActiveAccountPlatform.fixed(
      accounts: accounts,
      factory: build,
      accountId: LoginAccount.unsavedId,
      interactiveMaxWait: interactiveWait,
    );
    final loginLease = GovernorLoginLease(webViewLease);

    final deleteContent = DeleteContent(
      content: content,
      gallery: parts.gallery,
      cache: parts.cache,
    );
    return AppComposition._(
      background: background,
      holder: holderId,
      parts: parts,
      governor: governor,
      platform: platform,
      loginPlatform: loginPlatform,
      loginLease: loginLease,
      targets: targets,
      content: content,
      accounts: accounts,
      activity: activity,
      checkRuns: checkRuns,
      leases: leases,
      deleteContent: deleteContent,
      runCheck: RunCheck(
        platform: platform,
        signals: platform,
        targets: targets,
        content: content,
        accounts: accounts,
        checkRuns: checkRuns,
        activity: activity,
        settings: parts.settings,
        clock: clock,
      ),
      backfillHistory: BackfillHistory(
        platform: platform,
        targets: targets,
        content: content,
        accounts: accounts,
        settings: parts.settings,
        clock: clock,
      ),
      syncHighlights: SyncHighlights(
        platform: platform,
        targets: targets,
        content: content,
        accounts: accounts,
        settings: parts.settings,
        clock: clock,
      ),
      downloadPending: DownloadPending(
        content: content,
        targets: targets,
        activity: activity,
        platform: platform,
        cache: parts.cache,
        gallery: parts.gallery,
        storage: parts.storage,
        clock: clock,
        leases: leases,
        holder: '$holderId-dl',
        displayName: displayNameFor,
        relativeDir: relativeDirFor,
        findExisting: parts.findExisting,
      ),
      applyRetention: ApplyRetention(
        settings: parts.settings,
        content: content,
        checkRuns: checkRuns,
        deleteContent: deleteContent,
        clock: clock,
      ),
      detectGaps: DetectGaps(
        checkRuns: checkRuns,
        settings: parts.settings,
        activity: activity,
      ),
    );
  }

  static int _seq = 0;

  /// True for a WorkManager isolate.
  final bool background;

  /// This isolate's unique holder id (governor and WebView lease).
  final String holder;

  /// The parts this composition was built from.
  final CompositionParts parts;

  /// This isolate's request governor.
  final RequestGovernor governor;

  /// The platform of the active account (also the `ContentSignals`).
  final ActiveAccountPlatform platform;

  /// The platform the login flow verifies a new session with: always the
  /// staging account id (`LoginAccount.unsavedId`), never the active account.
  final ContentPlatform loginPlatform;

  /// The WebView lease S-02 holds (key -1), shared with page mode.
  final LoginLease loginLease;

  /// Checks stories or posts.
  final RunCheck runCheck;

  /// Fetches the post history of a target, one page per step.
  final BackfillHistory backfillHistory;

  /// Saves the highlights of targets that have them on.
  final SyncHighlights syncHighlights;

  /// Downloads pending media.
  final DownloadPending downloadPending;

  /// Deletes content older than the retention window.
  final ApplyRetention applyRetention;

  /// Finds gaps in story checks.
  final DetectGaps detectGaps;

  /// Deletes content.
  final DeleteContent deleteContent;

  /// Targets.
  final TargetRepo targets;

  /// Content.
  final ContentRepo content;

  /// Accounts.
  final AccountRepo accounts;

  /// Activity.
  final ActivityRepo activity;

  /// Check runs.
  final CheckRunRepo checkRuns;

  /// Governor leases.
  final GovernorLeaseRepo leases;

  /// Settings.
  SettingsRepo get settings => parts.settings;

  /// The scheduler.
  Scheduler get scheduler => parts.scheduler;

  /// The clock.
  Clock get clock => parts.clock;

  /// The log.
  DiagnosticLog get log => parts.log;

  /// Work that runs at every start of an isolate, after the database opens
  /// (foreground start and each background task). Each step is independent:
  /// a failing step is logged (type only) and the others still run.
  ///
  /// 1. Reports a pending crash (`APP_CRASH`).
  /// 2. Removes orphan `.part` files, unless a download holds the downloads
  ///    lease (its `.part` of a DOWNLOADING row is not an orphan; the running
  ///    download cleans up on its own).
  /// 3. Removes thumbnails that belong to no media file. Skipped when the
  ///    library cannot be read, so a failed read never deletes thumbnails.
  /// 4. Gap detection (EC-10, EC-11).
  Future<StartReport> start() async {
    var crash = false;
    var parts0 = 0;
    var thumbs = 0;
    var skipped = false;
    Gap? gap;

    final marker = parts.crashMarker;
    if (marker != null) {
      crash = await _step(
        'crash_report',
        () => reportPendingCrash(activity, clock, marker: marker),
        false,
      );
    }

    final lease = await _step<GovernorLease?>(
      'part_sweep_lease',
      () => leases.acquire(
        accountId: DownloadPending.leaseKey,
        holder: '$holder-sweep',
        // At least the downloads' own ttl: the lease table treats a lease
        // that ends further away than the asked ttl as a clock jump and
        // takes it over.
        ttl: DownloadPending.leaseTtl,
        initialBucket: GovernorBucket(
          tokens: 0,
          lastRefillAt: clock.now().toUtc(),
        ),
      ),
      null,
    );
    if (lease == null) {
      skipped = true;
    } else {
      try {
        parts0 = await _step('part_sweep', () async {
          final pending = await content.pendingMedia();
          return parts.cache.cleanupOrphans({
            for (final p in pending) p.file.id,
          });
        }, 0);
      } finally {
        await _step(
          'part_sweep_release',
          () => leases.release(
            accountId: DownloadPending.leaseKey,
            holder: '$holder-sweep',
          ),
          null,
        );
      }
    }

    thumbs = await _step('thumbnail_sweep', () async {
      final all = await content.watchLibrary(ContentFilter()).first;
      final live = {
        for (final c in all)
          for (final m in c.media) m.id,
      };
      return parts.cache.cleanupOrphanThumbnails(live);
    }, 0);

    gap = await _step('gap_detection', () => detectGaps(clock.now()), null);

    return StartReport(
      crashReported: crash,
      partsRemoved: parts0,
      thumbnailsRemoved: thumbs,
      partSweepSkipped: skipped,
      gap: gap,
    );
  }

  /// Removes a staging session left under [LoginAccount.unsavedId] by a login
  /// that was killed before it finished (S-02 verifies under that id).
  ///
  /// Call it only in the foreground isolate, at start: a background task
  /// could otherwise wipe the session of a login that is running. A failure
  /// is ignored and not logged with values.
  Future<void> clearStagingSession() async {
    try {
      await parts.sessions.clear(LoginAccount.unsavedId);
    } on Object catch (error) {
      log.log(
        LogLevel.warn,
        'start',
        'staging_clear_failed type=${error.runtimeType}',
      );
    }
  }

  Future<T> _step<T>(String name, Future<T> Function() body, T fallback) async {
    try {
      return await body();
    } on Object catch (error) {
      log.log(
        LogLevel.warn,
        'start',
        'step_failed step=$name type=${error.runtimeType}',
      );
      return fallback;
    }
  }

  /// Registers the periodic tasks from the current settings now, and again
  /// whenever the interval or Wi-Fi-only setting changes. Call it at every
  /// foreground start: a force-stop removes WorkManager work, and this puts
  /// it back (a reboot keeps it, WorkManager restores it itself).
  ///
  /// Returns the subscription; cancel it in [dispose].
  StreamSubscription<void> keepScheduleApplied() {
    final sub = settings
        .watch()
        .map((s) => (s.storyIntervalMin, s.postIntervalMin, s.wifiOnly))
        .distinct()
        .asyncMap((v) async {
          try {
            await scheduler.apply(
              storyMin: v.$1,
              postMin: v.$2,
              wifiOnly: v.$3,
            );
          } on Object catch (error) {
            log.log(
              LogLevel.warn,
              'scheduler',
              'apply_failed type=${error.runtimeType}',
            );
          }
        })
        .listen((_) {});
    _subscriptions.add(sub);
    return sub;
  }

  final List<StreamSubscription<void>> _subscriptions = [];

  /// Stops the schedule subscription and closes the parts (database, HTTP
  /// client). Safe to call twice.
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    for (final close in parts.closers) {
      try {
        await close();
      } on Object catch (error) {
        log.log(
          LogLevel.warn,
          'start',
          'close_failed type=${error.runtimeType}',
        );
      }
    }
  }
}
