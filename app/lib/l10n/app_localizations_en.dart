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

  @override
  String libDeletePartial(int deleted, int failed) {
    return '$deleted deleted, $failed couldn\'t be deleted';
  }

  @override
  String get libDeleting => 'Deleting…';

  @override
  String get onbWelcomeTagline =>
      'Save stories automatically, before they disappear.';

  @override
  String get onbRiskTitle => 'Before you continue';

  @override
  String get onbRisk1 =>
      'Storize uses an Instagram account to view stories. Instagram may challenge or ban that account.';

  @override
  String get onbRisk2 =>
      'People you track will see that account in their story viewers.';

  @override
  String get onbRisk3 => 'Use a dedicated account, not your personal one.';

  @override
  String get onbRisk4 =>
      'Only track your own/client accounts, people who agreed, or public creators.';

  @override
  String get onbRiskCheckbox => 'I understand these risks';

  @override
  String get onbContinue => 'Continue';

  @override
  String get onbLoginInfo =>
      'Only the login session is saved, never your password.';

  @override
  String get onbLoginHelp => 'Why use a dedicated account?';

  @override
  String get onbLoginHelpBody =>
      'Storize views stories as this account, and Instagram may challenge or ban it. A dedicated account keeps your personal one safe.';

  @override
  String get onbLoginClose => 'Close';

  @override
  String get onbLoginCancel => 'Cancel login';

  @override
  String get onbLoginConnecting => 'Connecting…';

  @override
  String onbLoginConnected(String username) {
    return 'Connected as @$username';
  }

  @override
  String get onbLoginPageLoading => 'Loading the login page';

  @override
  String get onbTryAgain => 'Try again';

  @override
  String get onbErrNetworkTitle => 'No internet';

  @override
  String get onbErrNetworkBody => 'Check your connection and try again.';

  @override
  String get onbErrPageTitle => 'The page didn\'t load';

  @override
  String get onbErrPageBody => 'Instagram\'s login page could not be loaded.';

  @override
  String get onbErrCheckpointTitle => 'Instagram needs to verify this account';

  @override
  String get onbErrCheckpointBody =>
      'Open Instagram on another device, confirm it\'s you, then try again. Or use another account.';

  @override
  String get onbErrUnusableTitle => 'Couldn\'t connect this account';

  @override
  String get onbErrUnusableBody => 'Try again or use another account.';

  @override
  String get onbErrWrongAccountTitle => 'Account not switched';

  @override
  String onbErrWrongAccountBody(String username) {
    return 'Checks keep using @$username.';
  }

  @override
  String get onbErrBusyTitle => 'Login isn\'t available right now';

  @override
  String get onbErrBusyBody =>
      'Storize is using the web engine for a check. Try again in a moment.';

  @override
  String get onbErrCancelledTitle => 'Login cancelled';

  @override
  String get onbErrCancelledBody => 'No account was connected.';

  @override
  String onbSwitchTitle(String username) {
    return 'Switch to @$username?';
  }

  @override
  String get onbSwitchBody => 'Checks will use this account from now on.';

  @override
  String get onbSwitchConfirm => 'Switch';

  @override
  String get onbSwitchKeep => 'Keep current';

  @override
  String get onbSetupEyebrow => 'STEP 3 OF 3 · SETUP';

  @override
  String get onbSetupIntro =>
      'Android may stop background checks to save battery. These steps keep your archive complete.';

  @override
  String get onbNotifTitle => 'Notifications';

  @override
  String get onbNotifBody => 'Get told about new stories and login problems.';

  @override
  String get onbAllow => 'Allow';

  @override
  String get onbOpenAppSettings => 'Open app settings';

  @override
  String get onbBatteryTitle => 'Battery optimization';

  @override
  String get onbBatteryBody =>
      'Set Storize to Unrestricted in battery settings.';

  @override
  String get onbBatteryOpen => 'Open battery settings';

  @override
  String onbOemTitle(String oem) {
    return 'Extra step for $oem';
  }

  @override
  String get onbOemDetected => 'Detected on this phone.';

  @override
  String get onbOemSamsung =>
      '1. Settings > Battery > Background usage limits\n2. Never sleeping apps > + Storize';

  @override
  String get onbOemXiaomi =>
      '1. Settings > Apps > Manage apps > Storize\n2. Autostart on, Battery saver > No restrictions';

  @override
  String get onbOemOppo =>
      '1. Settings > Battery > Storize\n2. Allow background activity and auto-launch';

  @override
  String get onbOemVivo =>
      '1. Settings > Battery > Background power consumption\n2. Storize > Allow';

  @override
  String get onbOemHuawei =>
      '1. Settings > Battery > App launch > Storize\n2. Manage manually: auto-launch, secondary launch, run in background';

  @override
  String get onbOemOther =>
      'Open your phone\'s battery settings and allow Storize to run in the background and start automatically.';

  @override
  String get onbOemSamsungName => 'Samsung';

  @override
  String get onbOemXiaomiName => 'Xiaomi';

  @override
  String get onbOemOppoName => 'Oppo or Realme';

  @override
  String get onbOemVivoName => 'Vivo';

  @override
  String get onbOemHuaweiName => 'Huawei';

  @override
  String get onbOemOtherName => 'your phone';

  @override
  String get onbStorageTitle => 'Storage';

  @override
  String get onbStorageBody => 'Needed to save into your gallery.';

  @override
  String get onbBatteryWarning =>
      'Without the battery step, checks may be delayed or missed.';

  @override
  String get onbDone => 'Done';

  @override
  String get onbSkip => 'Skip for now';

  @override
  String get onbChecking => 'Checking';
}
