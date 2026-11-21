/// In-memory fakes of every `storize_domain` port, for tests in any package.
///
/// Not exported from `storize_domain.dart`, so production code cannot depend
/// on them by accident.
library;

export 'src/testing/fake_account_repo.dart';
export 'src/testing/fake_activity_repo.dart';
export 'src/testing/fake_check_run_repo.dart';
export 'src/testing/fake_clock.dart';
export 'src/testing/fake_content_platform.dart';
export 'src/testing/fake_content_repo.dart';
export 'src/testing/fake_content_signals.dart';
export 'src/testing/fake_diagnostic_log.dart';
export 'src/testing/fake_gallery_store.dart';
export 'src/testing/fake_governor_lease_repo.dart';
export 'src/testing/fake_media_cache.dart';
export 'src/testing/fake_scheduler.dart';
export 'src/testing/fake_session_store.dart';
export 'src/testing/fake_settings_repo.dart';
export 'src/testing/fake_storage_info.dart';
export 'src/testing/fake_target_repo.dart';
