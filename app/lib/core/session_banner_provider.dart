import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The banner to show, or null when the session is healthy (or absent).
///
/// Derived from a single `AccountRepo.watchActive()` subscription. Only
/// NEEDS_RELOGIN and RESTRICTED produce a banner (UX section 3).
final sessionBannerProvider = StreamProvider<SessionBannerKind?>((ref) {
  final repo = ref.watch(accountRepoProvider);
  return repo.watchActive().map(_bannerFor);
});

SessionBannerKind? _bannerFor(LoginAccount? account) =>
    switch (account?.status) {
      AccountStatus.needsRelogin => SessionBannerKind.needsRelogin,
      AccountStatus.restricted => SessionBannerKind.restricted,
      _ => null,
    };
