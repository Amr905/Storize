import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The active login account. The single `watchActive` subscription that the
/// session banner and the Targets screen (T-030) share.
final activeAccountProvider = StreamProvider<LoginAccount?>(
  (ref) => ref.watch(accountRepoProvider).watchActive(),
);

/// The banner to show, or null when the session is healthy (or absent).
///
/// Derived from a single `AccountRepo.watchActive()` subscription. Only
/// NEEDS_RELOGIN and RESTRICTED produce a banner (UX section 3).
final sessionBannerProvider = Provider<AsyncValue<SessionBannerKind?>>(
  (ref) => ref.watch(activeAccountProvider).whenData(_bannerFor),
);

SessionBannerKind? _bannerFor(LoginAccount? account) =>
    switch (account?.status) {
      AccountStatus.needsRelogin => SessionBannerKind.needsRelogin,
      AccountStatus.restricted => SessionBannerKind.restricted,
      _ => null,
    };
