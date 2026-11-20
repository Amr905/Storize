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
  String stepSemantics(int number, String title, String status) {
    return 'Step $number, $title, $status';
  }

  @override
  String statTileSemantics(String label, String value) {
    return '$label: $value';
  }

  @override
  String kindSwitchSemantics(String label, int count) {
    return '$label, $count';
  }

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

  @override
  String get lockTitle => 'Storize is locked';

  @override
  String get lockWrongPin => 'Wrong PIN';

  @override
  String get lockUnlockWithBiometrics => 'Unlock with fingerprint';

  @override
  String get lockBiometricReason => 'Unlock Storize';

  @override
  String get lockLoadFailed => 'Couldn\'t check the app lock.';

  @override
  String get lockResetTitle => 'App lock was reset';

  @override
  String get lockResetBody =>
      'Android cleared Storize\'s saved lock data. Create a new PIN to keep the app locked.';

  @override
  String get pinSetupTitle => 'Create a PIN';

  @override
  String get pinSetupHint => 'Use 4 to 6 digits.';

  @override
  String get pinSetupConfirmTitle => 'Enter the PIN again';

  @override
  String get pinSetupMismatch => 'The PINs don\'t match. Try again.';

  @override
  String get pinSetupContinue => 'Continue';

  @override
  String get pinSetupConfirm => 'Save PIN';

  @override
  String get pinSetupCancel => 'Cancel';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockSubtitle =>
      'Ask for your fingerprint or PIN when Storize opens.';

  @override
  String get settingsAppLockNote =>
      'Files saved to your gallery are not protected by the app lock.';

  @override
  String get appLockChooseTitle => 'Turn on app lock';

  @override
  String get appLockChooseBiometric => 'Use fingerprint';

  @override
  String get appLockChoosePin => 'Use a PIN';

  @override
  String get appLockEnableReason =>
      'Confirm your fingerprint to turn on app lock';

  @override
  String get appLockEnabled => 'App lock is on';

  @override
  String get appLockEnableFailed => 'App lock was not turned on';

  @override
  String get appLockDisabled => 'App lock is off';

  @override
  String get appLockConfirmTitle => 'Confirm it\'s you';

  @override
  String get appLockDisableReason => 'Confirm to turn off app lock';

  @override
  String get lockStorageUnreadable =>
      'Couldn\'t read the saved lock. Try again.';

  @override
  String get lockBiometricUnavailable =>
      'Fingerprint is not available right now. Try again.';

  @override
  String get libFilterTooltip => 'Filters';

  @override
  String get libStoriesTab => 'Stories';

  @override
  String get libPostsTab => 'Posts';

  @override
  String libSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get libCancelSelection => 'Cancel selection';

  @override
  String get libDelete => 'Delete';

  @override
  String get libDeleteTooltip => 'Delete (deletes from your gallery too)';

  @override
  String get libShare => 'Share';

  @override
  String get libCancel => 'Cancel';

  @override
  String libDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Delete $_temp0?';
  }

  @override
  String get libDeleteBody =>
      'They\'ll also be removed from your gallery. This can\'t be undone.';

  @override
  String libDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items deleted',
      one: '1 item deleted',
    );
    return '$_temp0';
  }

  @override
  String libDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items couldn\'t be deleted',
      one: '1 item couldn\'t be deleted',
    );
    return '$_temp0';
  }

  @override
  String get libShareNothing =>
      'Nothing to share yet. Files are still downloading.';

  @override
  String get libShareFailed => 'Couldn\'t share these items.';

  @override
  String get libCheckRunning => 'Checking for new items…';

  @override
  String libCheckDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Check finished. $count new items.',
      one: 'Check finished. 1 new item.',
      zero: 'Check finished. Nothing new.',
    );
    return '$_temp0';
  }

  @override
  String get libCheckFailed => 'Couldn\'t check right now. Try again later.';

  @override
  String get libCheckNow => 'Check now';

  @override
  String get libEmptyNoTargetsTitle => 'Nothing saved yet';

  @override
  String get libEmptyNoTargetsBody => 'Add an account to start archiving.';

  @override
  String get libAddAccount => 'Add account';

  @override
  String get libEmptyStoriesTitle => 'No stories yet';

  @override
  String get libEmptyPostsTitle => 'No posts yet';

  @override
  String get libWaitingStories => 'Waiting for new stories.';

  @override
  String get libWaitingPosts => 'Waiting for new posts.';

  @override
  String libWaitingStoriesAt(String time) {
    return 'Waiting for new stories. Last check $time.';
  }

  @override
  String libWaitingPostsAt(String time) {
    return 'Waiting for new posts. Last check $time.';
  }

  @override
  String get libFilteredStories => 'No stories match these filters.';

  @override
  String get libFilteredPosts => 'No posts match these filters.';

  @override
  String get libClearFilters => 'Clear filters';

  @override
  String get libFiltersTitle => 'Filters';

  @override
  String get libFilterAccounts => 'Accounts';

  @override
  String get libFilterKind => 'Kind';

  @override
  String get libFilterDate => 'Date';

  @override
  String get libFilterType => 'Type';

  @override
  String get libDateToday => 'Today';

  @override
  String get libDateYesterday => 'Yesterday';

  @override
  String get libDate7 => 'Last 7 days';

  @override
  String get libDate30 => 'Last 30 days';

  @override
  String get libDateCustom => 'Custom…';

  @override
  String libDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get libTypeAll => 'All';

  @override
  String get libTypePhotos => 'Photos';

  @override
  String get libTypeVideos => 'Videos';

  @override
  String get libTypeCarousels => 'Carousels';

  @override
  String get libTypeReels => 'Reels';

  @override
  String get libApply => 'Apply';

  @override
  String get libClear => 'Clear';

  @override
  String get libRemoveFilter => 'Remove filter';

  @override
  String libAccountNew(int count) {
    return '$count new';
  }

  @override
  String libAccountCount(int count) {
    return '$count';
  }

  @override
  String libTileStory(String account, String type, String when) {
    return 'Story by $account, $type, $when';
  }

  @override
  String libTilePost(String account, String type, String when) {
    return 'Post by $account, $type, $when';
  }

  @override
  String get libTilePhoto => 'photo';

  @override
  String get libTileVideo => 'video';

  @override
  String libTileVideoDuration(String duration) {
    return 'video, $duration';
  }

  @override
  String libTileCarousel(int count) {
    return 'carousel, $count items';
  }

  @override
  String get libTileReel => 'reel';

  @override
  String libWhen(String day, String time) {
    return '$day $time';
  }

  @override
  String get libMissingTitle => 'This file is missing';

  @override
  String get libMissingBody => 'Remove it from your library?';

  @override
  String get libRemoveFromLibrary => 'Remove from library';
}
