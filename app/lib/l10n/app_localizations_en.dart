// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Storize';

  @override
  String get navLibrary => 'Library';

  @override
  String get navTargets => 'Targets';

  @override
  String get navActivity => 'Activity';

  @override
  String get navSettings => 'Settings';

  @override
  String get screenWelcome => 'Welcome';

  @override
  String get screenLogin => 'Log in to Instagram';

  @override
  String get screenSetup => 'Keep Storize running';

  @override
  String get screenLibrary => 'Library';

  @override
  String get screenStoryViewer => 'Story';

  @override
  String get screenPostViewer => 'Post';

  @override
  String get screenTargets => 'Targets';

  @override
  String get screenAddTarget => 'Add target';

  @override
  String get screenTargetDetail => 'Target details';

  @override
  String get screenActivity => 'Activity';

  @override
  String get screenSettings => 'Settings';

  @override
  String get screenAccount => 'Instagram account';

  @override
  String get screenLock => 'App lock';

  @override
  String placeholderTodo(String task) {
    return 'TODO($task)';
  }

  @override
  String get statusActive => 'Active';

  @override
  String get statusChecking => 'Checking';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusNotVisible => 'Not visible';

  @override
  String get statusUnavailable => 'Unavailable';

  @override
  String get statusError => 'Error';

  @override
  String get statusNeedsRelogin => 'Needs re-login';

  @override
  String get statusRestricted => 'Restricted';

  @override
  String get categoryOwn => 'Own / client';

  @override
  String get categoryConsented => 'Consented';

  @override
  String get categoryPublic => 'Public';

  @override
  String get bannerFix => 'Fix';

  @override
  String get bannerReloginTitle => 'Instagram login needs attention';

  @override
  String get bannerReloginBody => 'Checks are paused.';

  @override
  String get bannerRestrictedTitle => 'Instagram account restricted';

  @override
  String get bannerRestrictedBody => 'Checks are paused.';

  @override
  String get thumbNew => 'new';

  @override
  String get thumbBroken => 'Can\'t load';

  @override
  String get thumbSelected => 'selected';

  @override
  String get stepDone => 'Done';

  @override
  String get stepPending => 'To do';

  @override
  String get all => 'All';

  @override
  String get loading => 'Loading';

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get pinDelete => 'Delete';

  @override
  String get pinBiometric => 'Use biometrics';

  @override
  String pinProgress(int filled, int length) {
    return '$filled of $length digits entered';
  }

  @override
  String pinCooldown(String time) {
    return 'Try again in $time';
  }

  @override
  String get emptyNoDataTitle => 'Nothing here yet';

  @override
  String get emptyNoDataBody =>
      'Items will show up here when there is something to see.';

  @override
  String get emptyFilteredTitle => 'No matches';

  @override
  String get emptyFilteredBody => 'Try changing or clearing the filters.';

  @override
  String get errorNetworkTitle => 'No internet connection';

  @override
  String get errorNetworkBody => 'Check your connection and try again.';

  @override
  String get errorRateLimitedTitle => 'Instagram is limiting requests';

  @override
  String get errorRateLimitedBody => 'Storize will try again later.';

  @override
  String get errorPlatformChangedTitle => 'Instagram changed';

  @override
  String get errorPlatformChangedBody =>
      'Update Storize to keep saving content.';

  @override
  String get errorUnknownTitle => 'Something went wrong';

  @override
  String get errorUnknownBody => 'Please try again.';

  @override
  String get retry => 'Retry';
}
