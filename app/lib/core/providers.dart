/// Overridable providers for every domain port.
///
/// None of them has an implementation yet: reading one throws
/// [UnimplementedError] until `main` (real wiring, later tasks) or a test
/// overrides it, for example with the fakes from
/// `package:storize_domain/testing.dart`.
///
/// ```dart
/// ProviderScope(overrides: [
///   accountRepoProvider.overrideWithValue(FakeAccountRepo()),
/// ], child: ...)
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_domain/storize_domain.dart';

Never _unwired(String name) => throw UnimplementedError(
  '$name is not wired yet. Override it in main() or in the test.',
);

/// [TargetRepo].
final targetRepoProvider = Provider<TargetRepo>(
  (ref) => _unwired('targetRepoProvider'),
);

/// [ContentRepo].
final contentRepoProvider = Provider<ContentRepo>(
  (ref) => _unwired('contentRepoProvider'),
);

/// [AccountRepo].
final accountRepoProvider = Provider<AccountRepo>(
  (ref) => _unwired('accountRepoProvider'),
);

/// [ActivityRepo].
final activityRepoProvider = Provider<ActivityRepo>(
  (ref) => _unwired('activityRepoProvider'),
);

/// [CheckRunRepo].
final checkRunRepoProvider = Provider<CheckRunRepo>(
  (ref) => _unwired('checkRunRepoProvider'),
);

/// [SettingsRepo].
final settingsRepoProvider = Provider<SettingsRepo>(
  (ref) => _unwired('settingsRepoProvider'),
);

/// [GovernorLeaseRepo].
final governorLeaseRepoProvider = Provider<GovernorLeaseRepo>(
  (ref) => _unwired('governorLeaseRepoProvider'),
);

/// [ContentPlatform] (Instagram in the MVP).
final contentPlatformProvider = Provider<ContentPlatform>(
  (ref) => _unwired('contentPlatformProvider'),
);

/// [Scheduler] (background work).
final schedulerProvider = Provider<Scheduler>(
  (ref) => _unwired('schedulerProvider'),
);

/// [Clock].
final clockProvider = Provider<Clock>((ref) => _unwired('clockProvider'));

/// [GalleryStore].
final galleryStoreProvider = Provider<GalleryStore>(
  (ref) => _unwired('galleryStoreProvider'),
);

/// [MediaCache].
final mediaCacheProvider = Provider<MediaCache>(
  (ref) => _unwired('mediaCacheProvider'),
);

/// [StorageInfo].
final storageInfoProvider = Provider<StorageInfo>(
  (ref) => _unwired('storageInfoProvider'),
);

/// [SessionStore].
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => _unwired('sessionStoreProvider'),
);

/// [ShareService] (library, viewers). Does nothing until a share package is
/// wired in `main`.
final shareServiceProvider = Provider<ShareService>(
  (ref) => const NoOpShareService(),
);

/// [CheckNowAction]: pull-to-refresh and "Check now". A stub until T-017/T-021
/// wire `RunCheck`.
final checkNowActionProvider = Provider<CheckNowAction>(
  (ref) => const StubCheckNowAction(),
);

/// The [DeleteContent] use case, built from the repo and the ports.
final deleteContentProvider = Provider<DeleteContent>(
  (ref) => DeleteContent(
    content: ref.watch(contentRepoProvider),
    gallery: ref.watch(galleryStoreProvider),
    cache: ref.watch(mediaCacheProvider),
  ),
);
