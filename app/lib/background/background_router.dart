import 'package:storize_app/background/task_router.dart';
import 'package:storize_app/core/composition.dart';
import 'package:storize_domain/storize_domain.dart';

/// Builds the [TaskRouter] of [c]: each task name goes to its use case.
///
/// `check-*` tasks use [RunCheck] then [DownloadPending]; `download` uses
/// [DownloadPending]; `retention` uses [ApplyRetention]; `update-check` uses
/// the update checker and records the check time.
TaskRouter routerFor(AppComposition c) => TaskRouter(
  runCheck: c.runCheck.call,
  download: c.downloadPending.run,
  retention: c.applyRetention.call,
  updateCheck: () => runUpdateCheck(c),
  settings: c.settings,
  clock: c.clock,
  enqueuer: c.parts.enqueuer,
  log: c.log,
  notifier: c.parts.notifications,
);

/// Runs the GitHub release check and stores the time (`lastUpdateCheckAt`).
///
/// The checker never throws and returns `UpdateNone` on any failure. Showing
/// the result is T-023; here only the time is kept, so the UI can show "last
/// checked" and a failed check is not repeated before the next period.
Future<void> runUpdateCheck(AppComposition c) async {
  final state = await c.parts.updateChecker.checkForUpdate(
    currentVersion: c.parts.currentVersion,
  );
  final now = c.clock.now();
  await c.settings.update((s) => s.copyWith(lastUpdateCheckAt: now));
  c.log.log(
    LogLevel.info,
    'background',
    'update_check state=${state.runtimeType}',
  );
}
