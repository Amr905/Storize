// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name.
  ///
  /// In en, this message translates to:
  /// **'Storize'**
  String get appTitle;

  /// Bottom navigation label.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// Bottom navigation label.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get navTargets;

  /// Bottom navigation label.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// Bottom navigation label.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get screenWelcome;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Log in to Instagram'**
  String get screenLogin;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Keep Storize running'**
  String get screenSetup;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get screenLibrary;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get screenStoryViewer;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get screenPostViewer;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get screenTargets;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Add target'**
  String get screenAddTarget;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Target details'**
  String get screenTargetDetail;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get screenActivity;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get screenSettings;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Instagram account'**
  String get screenAccount;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get screenLock;

  /// Placeholder body shown until the screen task is implemented.
  ///
  /// In en, this message translates to:
  /// **'TODO({task})'**
  String placeholderTodo(String task);

  /// Status badge label.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// Status badge label.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get statusChecking;

  /// Status badge label.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// Status badge label.
  ///
  /// In en, this message translates to:
  /// **'Not visible'**
  String get statusNotVisible;

  /// Status badge label.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get statusUnavailable;

  /// Status badge label.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// Status badge label.
  ///
  /// In en, this message translates to:
  /// **'Needs re-login'**
  String get statusNeedsRelogin;

  /// Status badge label.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get statusRestricted;

  /// Target category tag.
  ///
  /// In en, this message translates to:
  /// **'Own / client'**
  String get categoryOwn;

  /// Target category tag.
  ///
  /// In en, this message translates to:
  /// **'Consented'**
  String get categoryConsented;

  /// Target category tag.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get categoryPublic;

  /// Session banner action.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get bannerFix;

  /// Session banner headline when the Instagram login needs attention.
  ///
  /// In en, this message translates to:
  /// **'Instagram login needs attention'**
  String get bannerReloginTitle;

  /// Session banner second line when the login needs attention.
  ///
  /// In en, this message translates to:
  /// **'Checks are paused.'**
  String get bannerReloginBody;

  /// Session banner headline when the Instagram account is restricted.
  ///
  /// In en, this message translates to:
  /// **'Instagram account restricted'**
  String get bannerRestrictedTitle;

  /// Session banner second line when the account is restricted.
  ///
  /// In en, this message translates to:
  /// **'Checks are paused.'**
  String get bannerRestrictedBody;

  /// Corner text marking a thumbnail as new (not yet viewed).
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get thumbNew;

  /// Placeholder text on a thumbnail whose media failed to load.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load'**
  String get thumbBroken;

  /// Semantics suffix for a selected thumbnail.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get thumbSelected;

  /// Setup step status when the step is complete.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get stepDone;

  /// Setup step status when the step is not complete.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get stepPending;

  /// Screen reader label of a setup step: number, title and status.
  ///
  /// In en, this message translates to:
  /// **'Step {number}, {title}, {status}'**
  String stepSemantics(int number, String title, String status);

  /// Screen reader label of a stat tile: caption then value.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String statTileSemantics(String label, String value);

  /// Screen reader label of a kind switch segment with a count.
  ///
  /// In en, this message translates to:
  /// **'{label}, {count}'**
  String kindSwitchSemantics(String label, int count);

  /// Account filter chip that clears the selection.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Screen reader label for loading indicators and skeletons.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// Semantics label of a control that expands a section.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// Semantics label of a control that collapses a section.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// PIN pad backspace key semantics label.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pinDelete;

  /// PIN pad fingerprint key semantics label.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get pinBiometric;

  /// PIN pad semantics label.
  ///
  /// In en, this message translates to:
  /// **'{filled} of {length} digits entered'**
  String pinProgress(int filled, int length);

  /// PIN pad cooldown.
  ///
  /// In en, this message translates to:
  /// **'Try again in {time}'**
  String pinCooldown(String time);

  /// No description provided for @emptyNoDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyNoDataTitle;

  /// No description provided for @emptyNoDataBody.
  ///
  /// In en, this message translates to:
  /// **'Items will show up here when there is something to see.'**
  String get emptyNoDataBody;

  /// No description provided for @emptyFilteredTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get emptyFilteredTitle;

  /// No description provided for @emptyFilteredBody.
  ///
  /// In en, this message translates to:
  /// **'Try changing or clearing the filters.'**
  String get emptyFilteredBody;

  /// No description provided for @errorNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetworkTitle;

  /// No description provided for @errorNetworkBody.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get errorNetworkBody;

  /// No description provided for @errorRateLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Instagram is limiting requests'**
  String get errorRateLimitedTitle;

  /// No description provided for @errorRateLimitedBody.
  ///
  /// In en, this message translates to:
  /// **'Storize will try again later.'**
  String get errorRateLimitedBody;

  /// No description provided for @errorPlatformChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Instagram changed'**
  String get errorPlatformChangedTitle;

  /// No description provided for @errorPlatformChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Update Storize to keep saving content.'**
  String get errorPlatformChangedBody;

  /// No description provided for @errorUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknownTitle;

  /// No description provided for @errorUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get errorUnknownBody;

  /// Retry button.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// S-14 heading.
  ///
  /// In en, this message translates to:
  /// **'Storize is locked'**
  String get lockTitle;

  /// S-14 error under the PIN dots.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get lockWrongPin;

  /// S-14 button that reopens the fingerprint prompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint'**
  String get lockUnlockWithBiometrics;

  /// Reason shown in the system fingerprint prompt when opening the app.
  ///
  /// In en, this message translates to:
  /// **'Unlock Storize'**
  String get lockBiometricReason;

  /// S-14 error when the lock settings cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check the app lock.'**
  String get lockLoadFailed;

  /// S-14 heading when the saved PIN is gone.
  ///
  /// In en, this message translates to:
  /// **'App lock was reset'**
  String get lockResetTitle;

  /// S-14 explanation of the reset state.
  ///
  /// In en, this message translates to:
  /// **'Android cleared Storize\'s saved lock data. Create a new PIN to keep the app locked.'**
  String get lockResetBody;

  /// PIN setup heading, first entry.
  ///
  /// In en, this message translates to:
  /// **'Create a PIN'**
  String get pinSetupTitle;

  /// PIN setup hint.
  ///
  /// In en, this message translates to:
  /// **'Use 4 to 6 digits.'**
  String get pinSetupHint;

  /// PIN setup heading, second entry.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN again'**
  String get pinSetupConfirmTitle;

  /// PIN setup error when the second entry differs.
  ///
  /// In en, this message translates to:
  /// **'The PINs don\'t match. Try again.'**
  String get pinSetupMismatch;

  /// PIN setup button after the first entry.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get pinSetupContinue;

  /// PIN setup button after the second entry.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get pinSetupConfirm;

  /// Semantics label of the close button on PIN setup and confirm screens.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pinSetupCancel;

  /// S-12 row title.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock;

  /// S-12 row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for your fingerprint or PIN when Storize opens.'**
  String get settingsAppLockSubtitle;

  /// S-12 note under the App lock row.
  ///
  /// In en, this message translates to:
  /// **'Files saved to your gallery are not protected by the app lock.'**
  String get settingsAppLockNote;

  /// Sheet title when choosing how to unlock.
  ///
  /// In en, this message translates to:
  /// **'Turn on app lock'**
  String get appLockChooseTitle;

  /// Sheet option.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get appLockChooseBiometric;

  /// Sheet option.
  ///
  /// In en, this message translates to:
  /// **'Use a PIN'**
  String get appLockChoosePin;

  /// Reason shown in the fingerprint prompt when turning the lock on.
  ///
  /// In en, this message translates to:
  /// **'Confirm your fingerprint to turn on app lock'**
  String get appLockEnableReason;

  /// Snackbar after turning the lock on.
  ///
  /// In en, this message translates to:
  /// **'App lock is on'**
  String get appLockEnabled;

  /// Snackbar when enabling failed or was cancelled.
  ///
  /// In en, this message translates to:
  /// **'App lock was not turned on'**
  String get appLockEnableFailed;

  /// Snackbar after turning the lock off.
  ///
  /// In en, this message translates to:
  /// **'App lock is off'**
  String get appLockDisabled;

  /// Heading of the screen that asks for authentication before turning the lock off.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get appLockConfirmTitle;

  /// Reason shown in the fingerprint prompt when turning the lock off.
  ///
  /// In en, this message translates to:
  /// **'Confirm to turn off app lock'**
  String get appLockDisableReason;

  /// S-14 message when secure storage cannot be read. No new PIN is offered.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the saved lock. Try again.'**
  String get lockStorageUnreadable;

  /// S-14 message for a fingerprint-only lock whose sensor is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint is not available right now. Try again.'**
  String get lockBiometricUnavailable;

  /// Library app bar: tooltip of the filter button (S-04).
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get libFilterTooltip;

  /// Library kind switch: stories segment.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get libStoriesTab;

  /// Library kind switch: posts segment.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get libPostsTab;

  /// Library selection mode app bar title.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String libSelectedCount(int count);

  /// Tooltip of the button that leaves selection mode.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get libCancelSelection;

  /// Library selection mode: delete action label and confirm button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get libDelete;

  /// Tooltip of the delete action in selection mode (BR-9).
  ///
  /// In en, this message translates to:
  /// **'Delete (deletes from your gallery too)'**
  String get libDeleteTooltip;

  /// Library selection mode: share action label.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get libShare;

  /// Cancel button of the library dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get libCancel;

  /// Delete confirmation title (S-04).
  ///
  /// In en, this message translates to:
  /// **'Delete {count, plural, =1{1 item} other{{count} items}}?'**
  String libDeleteTitle(int count);

  /// Delete confirmation body (BR-9).
  ///
  /// In en, this message translates to:
  /// **'They\'ll also be removed from your gallery. This can\'t be undone.'**
  String get libDeleteBody;

  /// Snackbar after a successful delete.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item deleted} other{{count} items deleted}}'**
  String libDeleted(int count);

  /// Snackbar when some items could not be deleted from the gallery.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item couldn\'t be deleted} other{{count} items couldn\'t be deleted}}'**
  String libDeleteFailed(int count);

  /// Snackbar when the selection has no saved files.
  ///
  /// In en, this message translates to:
  /// **'Nothing to share yet. Files are still downloading.'**
  String get libShareNothing;

  /// Snackbar when sharing failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share these items.'**
  String get libShareFailed;

  /// Snackbar/label while a check runs after pull-to-refresh.
  ///
  /// In en, this message translates to:
  /// **'Checking for new items…'**
  String get libCheckRunning;

  /// Snackbar with the check result.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Check finished. Nothing new.} =1{Check finished. 1 new item.} other{Check finished. {count} new items.}}'**
  String libCheckDone(int count);

  /// Snackbar when the check failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check right now. Try again later.'**
  String get libCheckFailed;

  /// Button in the "waiting for new items" empty state.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get libCheckNow;

  /// S-04 empty state (a) title.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get libEmptyNoTargetsTitle;

  /// S-04 empty state (a) body.
  ///
  /// In en, this message translates to:
  /// **'Add an account to start archiving.'**
  String get libEmptyNoTargetsBody;

  /// S-04 empty state (a) button.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get libAddAccount;

  /// S-04 empty state (b) title for stories.
  ///
  /// In en, this message translates to:
  /// **'No stories yet'**
  String get libEmptyStoriesTitle;

  /// S-04 empty state (b) title for posts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get libEmptyPostsTitle;

  /// S-04 empty state (b) body for stories without a last check time.
  ///
  /// In en, this message translates to:
  /// **'Waiting for new stories.'**
  String get libWaitingStories;

  /// S-04 empty state (b) body for posts without a last check time.
  ///
  /// In en, this message translates to:
  /// **'Waiting for new posts.'**
  String get libWaitingPosts;

  /// S-04 empty state (b) body for stories.
  ///
  /// In en, this message translates to:
  /// **'Waiting for new stories. Last check {time}.'**
  String libWaitingStoriesAt(String time);

  /// S-04 empty state (b) body for posts.
  ///
  /// In en, this message translates to:
  /// **'Waiting for new posts. Last check {time}.'**
  String libWaitingPostsAt(String time);

  /// S-04 empty state (c) for stories.
  ///
  /// In en, this message translates to:
  /// **'No stories match these filters.'**
  String get libFilteredStories;

  /// S-04 empty state (c) for posts.
  ///
  /// In en, this message translates to:
  /// **'No posts match these filters.'**
  String get libFilteredPosts;

  /// S-04 empty state (c) button.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get libClearFilters;

  /// S-05 sheet title.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get libFiltersTitle;

  /// S-05 section label.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get libFilterAccounts;

  /// S-05 section label.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get libFilterKind;

  /// S-05 section label.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get libFilterDate;

  /// S-05 section label.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get libFilterType;

  /// Date filter option and date header.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get libDateToday;

  /// Date header.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get libDateYesterday;

  /// Date filter option.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get libDate7;

  /// Date filter option.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get libDate30;

  /// Date filter option that opens the range picker.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get libDateCustom;

  /// Label of a custom date range.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String libDateRange(String from, String to);

  /// Type filter option.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libTypeAll;

  /// Type filter option.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get libTypePhotos;

  /// Type filter option.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get libTypeVideos;

  /// Type filter option (posts only).
  ///
  /// In en, this message translates to:
  /// **'Carousels'**
  String get libTypeCarousels;

  /// Type filter option (posts only).
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get libTypeReels;

  /// S-05 apply button.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get libApply;

  /// S-05 clear button.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get libClear;

  /// Tooltip of the delete icon on an active filter chip.
  ///
  /// In en, this message translates to:
  /// **'Remove filter'**
  String get libRemoveFilter;

  /// Account sub-header badge: unviewed items.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String libAccountNew(int count);

  /// Account sub-header item count.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String libAccountCount(int count);

  /// Semantics label of a story tile.
  ///
  /// In en, this message translates to:
  /// **'Story by {account}, {type}, {when}'**
  String libTileStory(String account, String type, String when);

  /// Semantics label of a post tile.
  ///
  /// In en, this message translates to:
  /// **'Post by {account}, {type}, {when}'**
  String libTilePost(String account, String type, String when);

  /// Tile semantics: photo.
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get libTilePhoto;

  /// Tile semantics: video without a known duration.
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get libTileVideo;

  /// Tile semantics: video with a duration.
  ///
  /// In en, this message translates to:
  /// **'video, {duration}'**
  String libTileVideoDuration(String duration);

  /// Tile semantics: carousel.
  ///
  /// In en, this message translates to:
  /// **'carousel, {count} items'**
  String libTileCarousel(int count);

  /// Tile semantics: reel.
  ///
  /// In en, this message translates to:
  /// **'reel'**
  String get libTileReel;

  /// Tile semantics: day and time.
  ///
  /// In en, this message translates to:
  /// **'{day} {time}'**
  String libWhen(String day, String time);

  /// Dialog title when a broken tile is tapped.
  ///
  /// In en, this message translates to:
  /// **'This file is missing'**
  String get libMissingTitle;

  /// Dialog body when a broken tile is tapped.
  ///
  /// In en, this message translates to:
  /// **'Remove it from your library?'**
  String get libMissingBody;

  /// Dialog confirm button for a missing file.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get libRemoveFromLibrary;

  /// Snackbar after a delete where some items could not be deleted from the gallery.
  ///
  /// In en, this message translates to:
  /// **'{deleted} deleted, {failed} couldn\'t be deleted'**
  String libDeletePartial(int deleted, int failed);

  /// Progress label (semantics) while a delete runs.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get libDeleting;

  /// S-01 headline.
  ///
  /// In en, this message translates to:
  /// **'Save stories automatically, before they disappear.'**
  String get onbWelcomeTagline;

  /// S-01 risk card title.
  ///
  /// In en, this message translates to:
  /// **'Before you continue'**
  String get onbRiskTitle;

  /// S-01 risk bullet.
  ///
  /// In en, this message translates to:
  /// **'Storize uses an Instagram account to view stories. Instagram may challenge or ban that account.'**
  String get onbRisk1;

  /// S-01 risk bullet.
  ///
  /// In en, this message translates to:
  /// **'People you track will see that account in their story viewers.'**
  String get onbRisk2;

  /// S-01 risk bullet.
  ///
  /// In en, this message translates to:
  /// **'Use a dedicated account, not your personal one.'**
  String get onbRisk3;

  /// S-01 risk bullet.
  ///
  /// In en, this message translates to:
  /// **'Only track your own/client accounts, people who agreed, or public creators.'**
  String get onbRisk4;

  /// S-01 checkbox.
  ///
  /// In en, this message translates to:
  /// **'I understand these risks'**
  String get onbRiskCheckbox;

  /// S-01 primary button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onbContinue;

  /// S-02 info strip.
  ///
  /// In en, this message translates to:
  /// **'Only the login session is saved, never your password.'**
  String get onbLoginInfo;

  /// S-02 help link.
  ///
  /// In en, this message translates to:
  /// **'Why use a dedicated account?'**
  String get onbLoginHelp;

  /// S-02 help dialog body.
  ///
  /// In en, this message translates to:
  /// **'Storize views stories as this account, and Instagram may challenge or ban it. A dedicated account keeps your personal one safe.'**
  String get onbLoginHelpBody;

  /// Dialog close button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get onbLoginClose;

  /// S-02 back button semantics label.
  ///
  /// In en, this message translates to:
  /// **'Cancel login'**
  String get onbLoginCancel;

  /// S-02 while the session is verified.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get onbLoginConnecting;

  /// S-02 success.
  ///
  /// In en, this message translates to:
  /// **'Connected as @{username}'**
  String onbLoginConnected(String username);

  /// S-02 progress bar semantics label.
  ///
  /// In en, this message translates to:
  /// **'Loading the login page'**
  String get onbLoginPageLoading;

  /// S-02 error button.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get onbTryAgain;

  /// S-02 error title.
  ///
  /// In en, this message translates to:
  /// **'No internet'**
  String get onbErrNetworkTitle;

  /// S-02 error body.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get onbErrNetworkBody;

  /// S-02 error title.
  ///
  /// In en, this message translates to:
  /// **'The page didn\'t load'**
  String get onbErrPageTitle;

  /// S-02 error body.
  ///
  /// In en, this message translates to:
  /// **'Instagram\'s login page could not be loaded.'**
  String get onbErrPageBody;

  /// S-02 error title.
  ///
  /// In en, this message translates to:
  /// **'Instagram needs to verify this account'**
  String get onbErrCheckpointTitle;

  /// S-02 error body.
  ///
  /// In en, this message translates to:
  /// **'Open Instagram on another device, confirm it\'s you, then try again. Or use another account.'**
  String get onbErrCheckpointBody;

  /// S-02 error title.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect this account'**
  String get onbErrUnusableTitle;

  /// S-02 error body.
  ///
  /// In en, this message translates to:
  /// **'Try again or use another account.'**
  String get onbErrUnusableBody;

  /// S-02 error title.
  ///
  /// In en, this message translates to:
  /// **'Account not switched'**
  String get onbErrWrongAccountTitle;

  /// S-02 error body.
  ///
  /// In en, this message translates to:
  /// **'Checks keep using @{username}.'**
  String onbErrWrongAccountBody(String username);

  /// S-02 error title.
  ///
  /// In en, this message translates to:
  /// **'Login isn\'t available right now'**
  String get onbErrBusyTitle;

  /// S-02 error body.
  ///
  /// In en, this message translates to:
  /// **'Storize is using the web engine for a check. Try again in a moment.'**
  String get onbErrBusyBody;

  /// S-02 error title.
  ///
  /// In en, this message translates to:
  /// **'Login cancelled'**
  String get onbErrCancelledTitle;

  /// S-02 error body.
  ///
  /// In en, this message translates to:
  /// **'No account was connected.'**
  String get onbErrCancelledBody;

  /// S-02 switch dialog title.
  ///
  /// In en, this message translates to:
  /// **'Switch to @{username}?'**
  String onbSwitchTitle(String username);

  /// S-02 switch dialog body.
  ///
  /// In en, this message translates to:
  /// **'Checks will use this account from now on.'**
  String get onbSwitchBody;

  /// S-02 switch dialog confirm.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get onbSwitchConfirm;

  /// S-02 switch dialog cancel.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get onbSwitchKeep;

  /// S-03 eyebrow.
  ///
  /// In en, this message translates to:
  /// **'STEP 3 OF 3 · SETUP'**
  String get onbSetupEyebrow;

  /// S-03 intro.
  ///
  /// In en, this message translates to:
  /// **'Android may stop background checks to save battery. These steps keep your archive complete.'**
  String get onbSetupIntro;

  /// S-03 step title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get onbNotifTitle;

  /// S-03 step body.
  ///
  /// In en, this message translates to:
  /// **'Get told about new stories and login problems.'**
  String get onbNotifBody;

  /// S-03 permission button.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onbAllow;

  /// S-03 link after a permission was denied twice.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get onbOpenAppSettings;

  /// S-03 step title.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization'**
  String get onbBatteryTitle;

  /// S-03 step body.
  ///
  /// In en, this message translates to:
  /// **'Set Storize to Unrestricted in battery settings.'**
  String get onbBatteryBody;

  /// S-03 button.
  ///
  /// In en, this message translates to:
  /// **'Open battery settings'**
  String get onbBatteryOpen;

  /// S-03 step title.
  ///
  /// In en, this message translates to:
  /// **'Extra step for {oem}'**
  String onbOemTitle(String oem);

  /// S-03 step subtitle.
  ///
  /// In en, this message translates to:
  /// **'Detected on this phone.'**
  String get onbOemDetected;

  /// Samsung steps.
  ///
  /// In en, this message translates to:
  /// **'1. Settings > Battery > Background usage limits\n2. Never sleeping apps > + Storize'**
  String get onbOemSamsung;

  /// Xiaomi steps.
  ///
  /// In en, this message translates to:
  /// **'1. Settings > Apps > Manage apps > Storize\n2. Autostart on, Battery saver > No restrictions'**
  String get onbOemXiaomi;

  /// Oppo/Realme steps.
  ///
  /// In en, this message translates to:
  /// **'1. Settings > Battery > Storize\n2. Allow background activity and auto-launch'**
  String get onbOemOppo;

  /// Vivo steps.
  ///
  /// In en, this message translates to:
  /// **'1. Settings > Battery > Background power consumption\n2. Storize > Allow'**
  String get onbOemVivo;

  /// Huawei steps.
  ///
  /// In en, this message translates to:
  /// **'1. Settings > Battery > App launch > Storize\n2. Manage manually: auto-launch, secondary launch, run in background'**
  String get onbOemHuawei;

  /// Other phones steps.
  ///
  /// In en, this message translates to:
  /// **'Open your phone\'s battery settings and allow Storize to run in the background and start automatically.'**
  String get onbOemOther;

  /// Manufacturer name.
  ///
  /// In en, this message translates to:
  /// **'Samsung'**
  String get onbOemSamsungName;

  /// Manufacturer name.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi'**
  String get onbOemXiaomiName;

  /// Manufacturer name.
  ///
  /// In en, this message translates to:
  /// **'Oppo or Realme'**
  String get onbOemOppoName;

  /// Manufacturer name.
  ///
  /// In en, this message translates to:
  /// **'Vivo'**
  String get onbOemVivoName;

  /// Manufacturer name.
  ///
  /// In en, this message translates to:
  /// **'Huawei'**
  String get onbOemHuaweiName;

  /// Manufacturer name (generic).
  ///
  /// In en, this message translates to:
  /// **'your phone'**
  String get onbOemOtherName;

  /// S-03 step title (Android 8-9).
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get onbStorageTitle;

  /// S-03 step body (Android 8-9).
  ///
  /// In en, this message translates to:
  /// **'Needed to save into your gallery.'**
  String get onbStorageBody;

  /// S-03 inline warning.
  ///
  /// In en, this message translates to:
  /// **'Without the battery step, checks may be delayed or missed.'**
  String get onbBatteryWarning;

  /// S-03 primary button.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get onbDone;

  /// S-03 secondary button.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onbSkip;

  /// S-03 step spinner semantics label.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get onbChecking;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
