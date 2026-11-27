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
  String get navTargets => 'Accounts';

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
  String get screenTargets => 'Accounts';

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
  String get stepAllowed => 'Allowed';

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
  String get lockSubtitle => 'Use your fingerprint or PIN';

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
  String storyPostedLine(String time, String ago) {
    return 'Posted $time · $ago';
  }

  @override
  String get storyAgoJustNow => 'just now';

  @override
  String storyAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String storyAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
      one: '1 h ago',
    );
    return '$_temp0';
  }

  @override
  String storyAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String storyAccount(String username) {
    return '@$username';
  }

  @override
  String get storyClose => 'Close';

  @override
  String get storyMute => 'Mute';

  @override
  String get storyUnmute => 'Unmute';

  @override
  String get storyPlay => 'Play';

  @override
  String get storyPause => 'Pause';

  @override
  String get storyScrubber => 'Video position';

  @override
  String get storyLoading => 'Loading…';

  @override
  String storyLinkSticker(String url) {
    return 'Link sticker: $url';
  }

  @override
  String get storyShare => 'Share';

  @override
  String get storyInfo => 'Info';

  @override
  String get storyDelete => 'Delete';

  @override
  String get storyDeleteTooltip => 'Delete (deletes from your gallery too)';

  @override
  String get storyDeleteTitle => 'Delete 1 item?';

  @override
  String get storyDeleteBody =>
      'They\'ll also be removed from your gallery. This can\'t be undone.';

  @override
  String get storyCancel => 'Cancel';

  @override
  String get storyDeleted => '1 item deleted';

  @override
  String get storyDeleteFailed => 'This item couldn\'t be deleted.';

  @override
  String get storyShareNothing =>
      'Nothing to share yet. The file is still downloading.';

  @override
  String get storyShareFailed => 'Couldn\'t share this item.';

  @override
  String get storyMissingTitle => 'This file is missing';

  @override
  String get storyMissingBody => 'Remove it from your library?';

  @override
  String get storyRemoveFromLibrary => 'Remove from library';

  @override
  String get storyCantPlay => 'This file can\'t be played.';

  @override
  String get storyPhotoUnavailable => 'Photo unavailable';

  @override
  String get storyInfoTitle => 'Details';

  @override
  String get storyInfoPosted => 'Posted';

  @override
  String get storyInfoDownloaded => 'Downloaded';

  @override
  String get storyInfoType => 'Type';

  @override
  String get storyTypePhoto => 'Photo';

  @override
  String get storyTypeVideo => 'Video';

  @override
  String get storyInfoDuration => 'Duration';

  @override
  String get storyInfoSize => 'Size';

  @override
  String storySizeKb(String kilobytes) {
    return '$kilobytes KB';
  }

  @override
  String storySizeMb(String megabytes) {
    return '$megabytes MB';
  }

  @override
  String get storyInfoItemId => 'Item ID';

  @override
  String get storyInfoFolder => 'Gallery folder';

  @override
  String get onbWelcomeTagline =>
      'Storize saves the stories and posts of the accounts you choose, straight to your gallery, in the background.';

  @override
  String get onbRiskTitle => 'Before you continue';

  @override
  String get onbRisk1 =>
      'Storize uses an Instagram account to view stories. Instagram may **challenge or ban** that account.';

  @override
  String get onbRisk2 =>
      'People you track will see that account **in their story viewers**.';

  @override
  String get onbRisk3 => 'Use a **dedicated account**, not your personal one.';

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

  @override
  String get actFilterAll => 'All';

  @override
  String get actFilterDownloads => 'Downloads';

  @override
  String get actFilterErrors => 'Errors';

  @override
  String get actFilterGaps => 'Gaps';

  @override
  String get actSubtitle => 'Last 7 days';

  @override
  String get actToday => 'Today';

  @override
  String get actYesterday => 'Yesterday';

  @override
  String get actEmptyTitle => 'No activity yet.';

  @override
  String actCheckDoneOk(int count) {
    return 'Checked $count accounts';
  }

  @override
  String get actCheckDoneOkSub => 'No errors';

  @override
  String actCheckFailedSub(int failed) {
    return '$failed failed';
  }

  @override
  String actCheckDoneFailed(int count, int failed) {
    return 'Checked $count accounts · $failed failed';
  }

  @override
  String actDownloadedStories(int count) {
    return '$count stories downloaded';
  }

  @override
  String actDownloadedPosts(int count) {
    return '$count posts downloaded';
  }

  @override
  String actRemovedBeforeDownload(String account) {
    return '$account · not an error';
  }

  @override
  String get actRemovedTitle => 'Story removed before download';

  @override
  String actGapTitle(String from, String to) {
    return 'Gap: no checks from $from to $to';
  }

  @override
  String get actGapSub => 'Android may have stopped Storize';

  @override
  String get actGap => 'Gap: no checks';

  @override
  String a11yMoreAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more accounts',
      one: '1 more account',
    );
    return '$_temp0';
  }

  @override
  String actGapRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get actFixBattery => 'Fix battery settings';

  @override
  String get actFix => 'Fix';

  @override
  String get actRateLimited => 'Instagram slowed us down';

  @override
  String get actRateLimitedSub => 'Checks were slowed down to be safe';

  @override
  String get actSessionProblem => 'Instagram login needs attention';

  @override
  String get actSessionProblemSub => 'Checks are paused until you log in again';

  @override
  String get actPlatformChanged => 'Instagram changed — update Storize';

  @override
  String get actPlatformChangedSub =>
      'Checks may fail until the app is updated';

  @override
  String get actPageModeUsed => 'Page mode used for a check';

  @override
  String get actStorageLow => 'Storage is low';

  @override
  String get actStoragePaused => 'Downloads paused';

  @override
  String get actStoragePausedSub => 'Storage is full';

  @override
  String get actTargetStatus => 'Account status changed';

  @override
  String get actFileMissing => 'File missing from gallery';

  @override
  String get actAppCrash => 'Storize closed unexpectedly';

  @override
  String actAccountHandle(String username) {
    return '@$username';
  }

  @override
  String get actAccountRemoved => 'Removed account';

  @override
  String tgtCountLimit(int count, int limit) {
    return '$count of $limit recommended';
  }

  @override
  String get tgtCatOwn => 'Own / Client';

  @override
  String get tgtCatOwnTitle => 'Own / Client account';

  @override
  String get tgtCatOwnHint => 'Accounts you or your clients own';

  @override
  String get tgtCatConsented => 'Person who agreed';

  @override
  String get tgtCatConsentedHint => 'They know and consented to archiving';

  @override
  String get tgtCatPublic => 'Public creator / brand';

  @override
  String get tgtCatPublicShort => 'Public creator';

  @override
  String get tgtCatPublicHint => 'Public account';

  @override
  String tgtErrRateLimited(int minutes) {
    return 'Instagram limit reached — try again in about $minutes min';
  }

  @override
  String get tgtAddShort => 'Add';

  @override
  String tgtMetaSaved(int count) {
    return '$count saved';
  }

  @override
  String get tgtMetaPausedByYou => 'Paused by you';

  @override
  String get tgtMetaPrivate => 'Private — not followed';

  @override
  String get tgtMetaGone => 'Account no longer exists';

  @override
  String get tgtCheckNow => 'Check now';

  @override
  String get tgtCheckNowDisabled => 'Log in again to check now.';

  @override
  String tgtCheckDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new items',
      one: '1 new item',
      zero: 'Nothing new',
    );
    return '$_temp0';
  }

  @override
  String get debugCheckNowUnmetered => 'Check now (debug, no limit)';

  @override
  String get tgtCheckFailed => 'The check could not run.';

  @override
  String get tgtRateLimitBar =>
      'Instagram is limiting requests. Storize has slowed checks down.';

  @override
  String tgtMetaChecked(String time) {
    return 'Checked $time';
  }

  @override
  String get tgtMetaNever => 'Not checked yet';

  @override
  String tgtMetaLastNew(String time) {
    return 'Last new $time';
  }

  @override
  String tgtMetaLine(String first, String second) {
    return '$first · $second';
  }

  @override
  String get tgtActionPause => 'Pause';

  @override
  String get tgtActionResume => 'Resume';

  @override
  String get tgtUpdateFailed => 'The change could not be saved.';

  @override
  String get tgtEmptyTitle => 'Track your first account';

  @override
  String get tgtEmptyBody =>
      'Add an Instagram account to start saving its stories and posts.';

  @override
  String get tgtAddAccount => 'Add account';

  @override
  String get tgtFormTitle => 'Add account';

  @override
  String get tgtClose => 'Close';

  @override
  String get tgtUsernameLabel => 'Username or profile link';

  @override
  String get tgtUsernameHint => '@username or instagram.com/name';

  @override
  String get tgtUsernameInvalid =>
      'Enter a valid Instagram username or profile link.';

  @override
  String get tgtCategoryLabel => 'Category *';

  @override
  String get tgtCategoryRequired => 'Choose a category.';

  @override
  String get tgtTrackLabel => 'Track';

  @override
  String get tgtTrackStories => 'Stories';

  @override
  String get tgtTrackPosts => 'Posts';

  @override
  String get tgtTrackReels => 'Reels';

  @override
  String get tgtTrackRequired => 'Choose at least one.';

  @override
  String get tgtTrackHint =>
      'Today\'s posts and stories are saved now. Pick a post history below for older posts.';

  @override
  String get tgtNoteLabel => 'Note (optional)';

  @override
  String get tgtNoteHint => 'e.g. consent by email 3/11';

  @override
  String get tgtNoteTooLong => 'Keep the note to 200 characters or fewer.';

  @override
  String tgtNotFound(String username) {
    return 'No Instagram account named $username.';
  }

  @override
  String tgtNotVisiblePrivate(String username, String login) {
    return '$username is private and $login doesn\'t follow it. Follow it first from Instagram.';
  }

  @override
  String tgtNotVisibleBlocked(String username) {
    return '$username can\'t be seen from the logged-in account.';
  }

  @override
  String tgtDuplicate(String username) {
    return 'Already tracked as $username.';
  }

  @override
  String get tgtOpen => 'Open';

  @override
  String get tgtSessionInactive => 'Log in again to add accounts.';

  @override
  String get tgtRestricted =>
      'Instagram restricted the login account. Checks are paused.';

  @override
  String tgtOverLimit(int limit) {
    return 'More than $limit accounts increases the risk of a ban.';
  }

  @override
  String get tgtAddAndVerify => 'Add & verify';

  @override
  String get tgtVerifying => 'Verifying…';

  @override
  String tgtAdded(String username) {
    return 'Tracking $username. First check running…';
  }

  @override
  String tgtAddedPending(String username) {
    return 'Added. Instagram asked us to slow down, so we\'ll look up @$username in a few minutes.';
  }

  @override
  String get tgtStatusPending => 'Waiting to look up';

  @override
  String get tdtStatusPending => 'Waiting to look up';

  @override
  String get postTypePhoto => 'Photo';

  @override
  String get postTypeVideo => 'Video';

  @override
  String get postTypeCarousel => 'Carousel';

  @override
  String get postTypeReel => 'Reel';

  @override
  String postCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String postSlideSemantics(int current, int total) {
    return 'Slide $current of $total';
  }

  @override
  String get postMoreTooltip => 'More';

  @override
  String get postShareAll => 'Share all slides';

  @override
  String postPostedOn(String when, String type) {
    return 'Posted $when · $type';
  }

  @override
  String get postCaptionMore => 'More';

  @override
  String get postCaptionLess => 'Less';

  @override
  String get postLinkTitle => 'Post link';

  @override
  String get postCopyLink => 'Copy link';

  @override
  String get postLinkCopied => 'Link copied';

  @override
  String get postInfoSlides => 'Slides';

  @override
  String postInfoSlideCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slides',
      one: '1 slide',
    );
    return '$_temp0';
  }

  @override
  String postDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete this post ($count files)?',
      one: 'Delete this post (1 file)?',
    );
    return '$_temp0';
  }

  @override
  String get postDeleteBody =>
      'Also removes them from your gallery. This can\'t be undone.';

  @override
  String get postDeleted => 'Post deleted';

  @override
  String get postDeleteFailed => 'This post couldn\'t be deleted.';

  @override
  String get postSlideMissingTitle => 'This slide\'s file is missing';

  @override
  String get postSlideMissingBody => 'It was moved or deleted outside Storize.';

  @override
  String get postRemoveSlide => 'Remove slide';

  @override
  String get postSlideRemoveFailed => 'This slide couldn\'t be removed.';

  @override
  String get postSlideNotDownloaded => 'Not downloaded';

  @override
  String get postSlideNotDownloadedBody =>
      'This slide didn\'t finish downloading.';

  @override
  String get setSectionInstagram => 'Instagram';

  @override
  String get setSectionChecking => 'Checking';

  @override
  String get setSectionNotifications => 'Notifications';

  @override
  String get setSectionStorage => 'Storage';

  @override
  String get setSectionSecurity => 'Security';

  @override
  String get setSectionAbout => 'About';

  @override
  String get setStoryInterval => 'Check stories every';

  @override
  String get setPostInterval => 'Check posts every';

  @override
  String setIntervalMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String setIntervalHours(int hours) {
    return '$hours h';
  }

  @override
  String get setPostOneHourWarning => 'More requests increase the ban risk.';

  @override
  String get setWifiOnly => 'Wi-Fi only';

  @override
  String get setKeepRunning => 'Keep Storize running';

  @override
  String get setWifiOnlyHint => 'Pause downloads on mobile data';

  @override
  String get setKeepRunningHint => 'Battery & background setup';

  @override
  String get setNotifyStories => 'New stories';

  @override
  String get setNotifyPosts => 'New posts';

  @override
  String get setNotifyLogin => 'Login problems';

  @override
  String get setNotifyLoginOffWarning => 'You may not notice when checks stop.';

  @override
  String get setStorageLocation => 'Saved to Pictures/Storize';

  @override
  String get setStorageCalculating => 'Calculating…';

  @override
  String get setStorageUnknown => 'Storage unknown';

  @override
  String setStorageUsedFree(String used, String free) {
    return 'Used $used · free $free';
  }

  @override
  String setStorageUsedOnly(String used) {
    return 'Used $used';
  }

  @override
  String get setStorageByAccount => 'Storage by account';

  @override
  String get setStorageNone => 'No downloads stored yet.';

  @override
  String setSizeGb(String value) {
    return '$value GB';
  }

  @override
  String setSizeMb(String value) {
    return '$value MB';
  }

  @override
  String setSizeKb(String value) {
    return '$value KB';
  }

  @override
  String setSizeBytes(String value) {
    return '$value B';
  }

  @override
  String get setKeepDownloads => 'Keep downloads';

  @override
  String get setKeepForever => 'Forever';

  @override
  String setKeepAfterDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'After $days days',
      one: 'After 1 day',
    );
    return '$_temp0';
  }

  @override
  String get setRetentionAfter => 'After';

  @override
  String get setRetentionDaysLabel => 'Days';

  @override
  String get setRetentionDaysError => 'Enter a whole number from 1 to 3650.';

  @override
  String get setRetentionConfirmTitle => 'Delete older downloads now?';

  @override
  String setRetentionConfirmBody(int days, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Items older than $days days ($_temp0, $size) will be deleted now.';
  }

  @override
  String get setRetentionConfirm => 'Delete now';

  @override
  String get setCancel => 'Cancel';

  @override
  String get setSave => 'Save';

  @override
  String setVersion(String version) {
    return 'Version $version';
  }

  @override
  String get setUpdateAvailable => 'Update available';

  @override
  String get setUpdateRequired => 'Update required';

  @override
  String setUpdateVersion(String version) {
    return 'v$version';
  }

  @override
  String accConnected(String date) {
    return 'Connected $date';
  }

  @override
  String get accNotConnected => 'Not connected';

  @override
  String get accHealthTitle => 'Health';

  @override
  String get accLastCheckLabel => 'Last successful check';

  @override
  String get accRateLimitLabel => 'Rate-limit events (7 days)';

  @override
  String accLastCheck(String time) {
    return 'Last successful check $time';
  }

  @override
  String get accLastCheckNever => 'No successful check yet';

  @override
  String accRateLimitEvents(int count) {
    return 'Rate-limit events (7 days): $count';
  }

  @override
  String get accNeedsReloginBody =>
      'Instagram ended the session or asked to confirm it\'s you. All checks are paused.';

  @override
  String get accRestrictedBody =>
      'Instagram may have restricted this account. Checks are stopped. Consider logging in with a different dedicated account.';

  @override
  String get accLogIn => 'Log in';

  @override
  String get accLogInAgain => 'Log in again';

  @override
  String get accLogInAnother => 'Log in with another account';

  @override
  String get accLogOut => 'Log out';

  @override
  String get accLogOutTitle => 'Log out of Instagram?';

  @override
  String get accLogOutBody =>
      'Stop all checks and remove the saved session? Your downloads and targets are kept.';

  @override
  String get accLogOutConfirm => 'Log out';

  @override
  String get tdtMenuTooltip => 'More actions';

  @override
  String get tdtRemove => 'Remove';

  @override
  String get tdtNotFound => 'This account is no longer tracked.';

  @override
  String get tdtCategoryLabel => 'Category';

  @override
  String get tdtNoteLabel => 'Note';

  @override
  String get tdtNoteNone => 'No note yet.';

  @override
  String get tdtEditCategory => 'Edit category';

  @override
  String get tdtEditNote => 'Edit note';

  @override
  String get tdtStatStories => 'Stories';

  @override
  String get tdtStatPosts => 'Posts';

  @override
  String get tdtStatSpace => 'Space';

  @override
  String tdtStatusNotVisible(String login) {
    return 'This account is private and $login doesn\'t follow it (or blocked it). Past downloads are kept.';
  }

  @override
  String get tdtStatusUnavailable => 'This account no longer exists.';

  @override
  String tdtStatusErrorBody(String error, String time) {
    return '$error ($time)';
  }

  @override
  String get tdtStatusErrorNone => 'The last check failed.';

  @override
  String get tdtLoginFallback => 'your account';

  @override
  String tdtMetaNewPost(String date) {
    return 'Last new post $date';
  }

  @override
  String get tdtRecentLabel => 'Recent';

  @override
  String get tdtSeeAll => 'See all';

  @override
  String get tdtEmptyStories => 'No stories saved yet.';

  @override
  String get tdtEmptyPosts => 'No posts saved yet.';

  @override
  String tdtRemoveTitle(String username) {
    return 'Stop tracking $username?';
  }

  @override
  String tdtRemoveCounts(int stories, int posts) {
    return '$stories stories and $posts posts are saved for this account.';
  }

  @override
  String get tdtRemoveKeep => 'Keep downloads';

  @override
  String get tdtRemoveDelete => 'Delete downloads too';

  @override
  String get tdtRemoveKeepHint => 'They stay in your Library and gallery';

  @override
  String get tdtRemoveDeleteHint =>
      'Also removes them from your gallery. Can\'t be undone';

  @override
  String get tdtRemoveConfirmDelete => 'Remove & delete';

  @override
  String tdtRemoved(String username) {
    return 'Stopped tracking $username.';
  }

  @override
  String get tdtRemovePartial =>
      'Some downloads could not be deleted. Try again.';

  @override
  String get tdtRemoveFailed => 'The account could not be removed.';

  @override
  String get ntfChannelNewStories => 'New stories';

  @override
  String get ntfChannelNewPosts => 'New posts';

  @override
  String get ntfChannelLoginProblems => 'Login problems';

  @override
  String get ntfChannelStorage => 'Storage';

  @override
  String get ntfChannelBackground => 'Background checks';

  @override
  String get ntfChannelExport => 'Export';

  @override
  String ntfStoriesFromAccount(int count, String username) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new stories from @$username',
      one: '1 new story from @$username',
    );
    return '$_temp0';
  }

  @override
  String ntfPostsFromAccount(int count, String username) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new posts from @$username',
      one: '1 new post from @$username',
    );
    return '$_temp0';
  }

  @override
  String ntfStoriesSummary(int count, int accounts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new stories',
      one: '1 new story',
    );
    String _temp1 = intl.Intl.pluralLogic(
      accounts,
      locale: localeName,
      other: '$accounts accounts',
      one: '1 account',
    );
    return '$_temp0 from $_temp1';
  }

  @override
  String ntfPostsSummary(int count, int accounts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new posts',
      one: '1 new post',
    );
    String _temp1 = intl.Intl.pluralLogic(
      accounts,
      locale: localeName,
      other: '$accounts accounts',
      one: '1 account',
    );
    return '$_temp0 from $_temp1';
  }

  @override
  String get ntfLoginNeeded =>
      'Instagram login needs attention — checks are paused';

  @override
  String get ntfStorageFull => 'Storage almost full — downloads paused';

  @override
  String ntfChecking(int accounts) {
    String _temp0 = intl.Intl.pluralLogic(
      accounts,
      locale: localeName,
      other: '$accounts accounts',
      one: '1 account',
    );
    return 'Checking $_temp0…';
  }

  @override
  String get tgtHistoryLabel => 'Post history';

  @override
  String get tgtHistoryNone => 'None';

  @override
  String get tgtHistoryToday => 'Today';

  @override
  String get tgtHistory7Days => 'Last 7 days';

  @override
  String get tgtHistory30Days => 'Last 30 days';

  @override
  String get tgtHistorySince => 'Since a date…';

  @override
  String tgtHistorySinceDate(String date) {
    return 'Since $date';
  }

  @override
  String get tgtHistoryAll => 'All';

  @override
  String get tgtHistoryAllHint =>
      'Large accounts can take many hours; downloads run slowly in the background';

  @override
  String get tgtHighlightsLabel => 'Highlights';

  @override
  String get tgtHighlightsHint =>
      'Saves the highlights now and the new items added to them later.';

  @override
  String get tdtHistoryTitle => 'Post history';

  @override
  String tdtHistoryRange(String range) {
    return 'Range: $range';
  }

  @override
  String get tdtHistoryChange => 'Change';

  @override
  String tdtHistoryRunning(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return 'Downloading history: $_temp0 so far · up to $date';
  }

  @override
  String tdtHistoryRunningNoDate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return 'Downloading history: $_temp0 so far';
  }

  @override
  String get tdtHistoryPaused => 'Paused';

  @override
  String get tdtHistoryDone => 'Done';

  @override
  String get tdtHistoryFailed =>
      'Stopped by an error. Resume history to try again.';

  @override
  String get tdtHistoryPause => 'Pause history';

  @override
  String get tdtHistoryResume => 'Resume history';

  @override
  String get tdtHistoryCancel => 'Stop history';

  @override
  String get tdtHighlightsLabel => 'Highlights';

  @override
  String get tdtHighlightsHint =>
      'Saves all pinned stories in the background, then new ones.';

  @override
  String get libHighlightsFilter => 'Highlights';

  @override
  String storyHighlightTitle(String title) {
    return 'Highlight: $title';
  }

  @override
  String get prvTitle => 'Preview';

  @override
  String get prvPreviewButton => 'Preview';

  @override
  String get prvPreviewAction => 'Preview & save';

  @override
  String get prvPrivateBadge => 'Private';

  @override
  String get prvCurrentStories => 'Current stories';

  @override
  String get prvRecentPosts => 'Recent posts';

  @override
  String get prvNoStories => 'No stories right now.';

  @override
  String get prvNoPosts => 'No posts to show.';

  @override
  String get prvSelectItem => 'Select item';

  @override
  String get prvSavedBadge => 'Saved';

  @override
  String prvSaveSelected(int count) {
    return 'Save selected ($count)';
  }

  @override
  String get prvSaveAll => 'Save all';

  @override
  String get prvSaving => 'Saving…';

  @override
  String get prvTrack => 'Track this account automatically';

  @override
  String get prvTracking => 'Tracking is on for this account.';

  @override
  String prvSaveDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count items to your gallery',
      one: 'Saved 1 item to your gallery',
    );
    return '$_temp0';
  }

  @override
  String prvSavePartial(int saved, int failed) {
    return 'Saved $saved, $failed failed';
  }

  @override
  String get prvSaveAlready => 'Already saved.';

  @override
  String prvSaveFailed(String reason) {
    return 'Couldn\'t save: $reason';
  }

  @override
  String get prvReasonBusy =>
      'another download is running, try again in a moment';

  @override
  String get prvReasonStorage => 'the phone is low on space';

  @override
  String get prvReasonPermission => 'Storize can\'t write to the gallery';

  @override
  String get prvReasonSession => 'log in again';

  @override
  String get prvReasonGeneric => 'the download failed';

  @override
  String get prvNotVisible =>
      'This account is private or can\'t be seen from the logged-in account.';

  @override
  String kindSwitchNewBadge(int count) {
    return '$count new';
  }

  @override
  String get libHighlightsTab => 'Highlights';

  @override
  String get libHighlightBadge => 'Highlight';

  @override
  String get setSectionAppearance => 'Appearance';

  @override
  String get setThemeSystem => 'System';

  @override
  String get setThemeLight => 'Light';

  @override
  String get setThemeDark => 'Dark';

  @override
  String get setThemeHint =>
      'System follows your phone\'s light or dark setting.';

  @override
  String get setThemeSemantics => 'Appearance';

  @override
  String get onbWelcomeHeadline => 'Stories disappear.\nYours don\'t have to.';

  @override
  String get onbPromiseAutoTitle => 'Automatic';

  @override
  String get onbPromiseAutoBody =>
      'New stories and posts are saved as they appear.';

  @override
  String get onbPromiseChooseTitle => 'Only who you choose';

  @override
  String get onbPromiseChooseBody =>
      'Storize saves the accounts you add, nothing else.';

  @override
  String get onbPromisePrivateTitle => 'Stays on your phone';

  @override
  String get onbPromisePrivateBody =>
      'No servers. Your login never leaves the device.';

  @override
  String get tdtSavedTitle => 'Saved';

  @override
  String storyInGallery(String username) {
    return 'In your gallery · Pictures/Storize/$username';
  }

  @override
  String get infoCaption => 'Caption';

  @override
  String get infoCopyCaption => 'Copy caption';

  @override
  String get infoCaptionCopied => 'Caption copied';

  @override
  String get infoLocation => 'Location';

  @override
  String get infoTagged => 'Tagged accounts';

  @override
  String get infoSavedOn => 'Saved on';
}
