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

  /// S-11 filter chip: every entry.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get actFilterAll;

  /// S-11 filter chip: download entries.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get actFilterDownloads;

  /// S-11 filter chip: problem entries.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get actFilterErrors;

  /// S-11 filter chip: gap entries.
  ///
  /// In en, this message translates to:
  /// **'Gaps'**
  String get actFilterGaps;

  /// S-11 subtitle under the title.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get actSubtitle;

  /// S-11 day header for today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get actToday;

  /// S-11 day header for yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get actYesterday;

  /// S-11 empty state title.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get actEmptyTitle;

  /// S-11 entry: a check finished without failures.
  ///
  /// In en, this message translates to:
  /// **'Checked {count} accounts · No errors'**
  String actCheckDoneOk(int count);

  /// S-11 entry: a check finished with failed accounts.
  ///
  /// In en, this message translates to:
  /// **'Checked {count} accounts · {failed} failed'**
  String actCheckDoneFailed(int count, int failed);

  /// S-11 entry: stories were downloaded for an account.
  ///
  /// In en, this message translates to:
  /// **'{count} stories downloaded · {account}'**
  String actDownloadedStories(int count, String account);

  /// S-11 entry: posts were downloaded for an account.
  ///
  /// In en, this message translates to:
  /// **'{count} posts downloaded · {account}'**
  String actDownloadedPosts(int count, String account);

  /// S-11 info entry (EC-7): content vanished before it was downloaded.
  ///
  /// In en, this message translates to:
  /// **'Removed before download · {account} · not an error'**
  String actRemovedBeforeDownload(String account);

  /// S-11 warning entry: no checks ran in this time range.
  ///
  /// In en, this message translates to:
  /// **'Gap: no checks from {from} to {to}'**
  String actGap(String from, String to);

  /// S-11 gap entry action; opens S-03.
  ///
  /// In en, this message translates to:
  /// **'Fix battery settings'**
  String get actFixBattery;

  /// S-11 session entry action; opens S-13.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get actFix;

  /// S-11 warning entry (EC-15).
  ///
  /// In en, this message translates to:
  /// **'Instagram slowed us down · checks slowed'**
  String get actRateLimited;

  /// S-11 error entry (EC-1/2); opens S-13.
  ///
  /// In en, this message translates to:
  /// **'Instagram login needs attention'**
  String get actSessionProblem;

  /// S-11 error entry (EC-14).
  ///
  /// In en, this message translates to:
  /// **'Instagram changed — update Storize'**
  String get actPlatformChanged;

  /// S-11 info entry: the headless page fallback ran.
  ///
  /// In en, this message translates to:
  /// **'Page mode used for a check'**
  String get actPageModeUsed;

  /// S-11 warning entry (NFR-13).
  ///
  /// In en, this message translates to:
  /// **'Storage is low'**
  String get actStorageLow;

  /// S-11 error entry (NFR-13).
  ///
  /// In en, this message translates to:
  /// **'Downloads paused · storage full'**
  String get actStoragePaused;

  /// S-11 info entry: a tracked account changed status.
  ///
  /// In en, this message translates to:
  /// **'Account status changed · {account}'**
  String actTargetStatus(String account);

  /// S-11 warning entry: a saved file is gone from the gallery.
  ///
  /// In en, this message translates to:
  /// **'File missing from gallery · {account}'**
  String actFileMissing(String account);

  /// S-11 error entry: crash marker from the previous run.
  ///
  /// In en, this message translates to:
  /// **'Storize closed unexpectedly'**
  String get actAppCrash;

  /// Account label in S-11 entries.
  ///
  /// In en, this message translates to:
  /// **'@{username}'**
  String actAccountHandle(String username);

  /// S-11 account label when the target was removed.
  ///
  /// In en, this message translates to:
  /// **'Removed account'**
  String get actAccountRemoved;

  /// S-12 section header.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get setSectionInstagram;

  /// S-12 section header.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get setSectionChecking;

  /// S-12 section header.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get setSectionNotifications;

  /// S-12 section header.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get setSectionStorage;

  /// S-12 section header.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get setSectionSecurity;

  /// S-12 section header.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get setSectionAbout;

  /// S-12 row title and sheet title for the story interval.
  ///
  /// In en, this message translates to:
  /// **'Check stories every'**
  String get setStoryInterval;

  /// S-12 row title and sheet title for the post interval.
  ///
  /// In en, this message translates to:
  /// **'Check posts every'**
  String get setPostInterval;

  /// Interval value shorter than an hour.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String setIntervalMinutes(int minutes);

  /// Interval value of whole hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String setIntervalHours(int hours);

  /// Hint under the post interval when it is 1 h.
  ///
  /// In en, this message translates to:
  /// **'More requests increase the ban risk.'**
  String get setPostOneHourWarning;

  /// S-12 switch: download only on an unmetered network.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get setWifiOnly;

  /// S-12 row that opens S-03 (background permissions).
  ///
  /// In en, this message translates to:
  /// **'Keep Storize running'**
  String get setKeepRunning;

  /// S-12 notification switch.
  ///
  /// In en, this message translates to:
  /// **'New stories'**
  String get setNotifyStories;

  /// S-12 notification switch.
  ///
  /// In en, this message translates to:
  /// **'New posts'**
  String get setNotifyPosts;

  /// S-12 notification switch.
  ///
  /// In en, this message translates to:
  /// **'Login problems'**
  String get setNotifyLogin;

  /// Warning shown while the login-problems notification is off.
  ///
  /// In en, this message translates to:
  /// **'You may not notice when checks stop.'**
  String get setNotifyLoginOffWarning;

  /// S-12 info row: the fixed gallery location.
  ///
  /// In en, this message translates to:
  /// **'Saved to Pictures/Storize'**
  String get setStorageLocation;

  /// S-12 storage row while figures load.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get setStorageCalculating;

  /// S-12 storage row when the figures cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Storage unknown'**
  String get setStorageUnknown;

  /// S-12 storage row.
  ///
  /// In en, this message translates to:
  /// **'Used {used} · free {free}'**
  String setStorageUsedFree(String used, String free);

  /// S-12 storage row when free space is unknown.
  ///
  /// In en, this message translates to:
  /// **'Used {used}'**
  String setStorageUsedOnly(String used);

  /// Sheet title of the per-account storage list.
  ///
  /// In en, this message translates to:
  /// **'Storage by account'**
  String get setStorageByAccount;

  /// Per-account storage sheet when nothing is stored.
  ///
  /// In en, this message translates to:
  /// **'No downloads stored yet.'**
  String get setStorageNone;

  /// Byte size in gigabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String setSizeGb(String value);

  /// Byte size in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String setSizeMb(String value);

  /// Byte size in kilobytes.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String setSizeKb(String value);

  /// Byte size under one kilobyte.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String setSizeBytes(String value);

  /// S-12 row title and sheet title for retention.
  ///
  /// In en, this message translates to:
  /// **'Keep downloads'**
  String get setKeepDownloads;

  /// Retention choice: keep everything.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get setKeepForever;

  /// S-12 retention value when retention is on.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{After 1 day} other{After {days} days}}'**
  String setKeepAfterDays(int days);

  /// Retention sheet radio label for the N-days option.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get setRetentionAfter;

  /// Retention sheet text field label (integer 1 to 3650).
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get setRetentionDaysLabel;

  /// Validation message for the retention days field.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 3650.'**
  String get setRetentionDaysError;

  /// Retention confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete older downloads now?'**
  String get setRetentionConfirmTitle;

  /// Retention confirmation body (FR-54).
  ///
  /// In en, this message translates to:
  /// **'Items older than {days} days ({count, plural, =1{1 item} other{{count} items}}, {size}) will be deleted now.'**
  String setRetentionConfirmBody(int days, int count, String size);

  /// Retention confirmation button.
  ///
  /// In en, this message translates to:
  /// **'Delete now'**
  String get setRetentionConfirm;

  /// Cancel button in S-12 sheets and dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get setCancel;

  /// Save button in the retention sheet.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get setSave;

  /// S-12 about row.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String setVersion(String version);

  /// S-12 row when a newer release exists.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get setUpdateAvailable;

  /// S-12 row when the installed version is below min-supported.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get setUpdateRequired;

  /// Version value of the update row.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String setUpdateVersion(String version);

  /// S-13 connection date.
  ///
  /// In en, this message translates to:
  /// **'Connected {date}'**
  String accConnected(String date);

  /// S-13 and S-12 gray status for no usable login.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get accNotConnected;

  /// S-13 health card title.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get accHealthTitle;

  /// S-13 health line.
  ///
  /// In en, this message translates to:
  /// **'Last successful check {time}'**
  String accLastCheck(String time);

  /// S-13 health line when no check has succeeded.
  ///
  /// In en, this message translates to:
  /// **'No successful check yet'**
  String get accLastCheckNever;

  /// S-13 health line.
  ///
  /// In en, this message translates to:
  /// **'Rate-limit events (7 days): {count}'**
  String accRateLimitEvents(int count);

  /// S-13 amber state message.
  ///
  /// In en, this message translates to:
  /// **'Instagram ended the session or asked for verification. Checks are paused.'**
  String get accNeedsReloginBody;

  /// S-13 red state message.
  ///
  /// In en, this message translates to:
  /// **'Instagram may have restricted this account. Checks are stopped. Consider logging in with a different dedicated account.'**
  String get accRestrictedBody;

  /// S-13 button when not connected.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get accLogIn;

  /// S-13 primary button in the needs re-login state.
  ///
  /// In en, this message translates to:
  /// **'Log in again'**
  String get accLogInAgain;

  /// S-13 primary button in the restricted state.
  ///
  /// In en, this message translates to:
  /// **'Log in with another account'**
  String get accLogInAnother;

  /// S-13 button that clears the saved session.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accLogOut;

  /// S-13 log-out confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Log out of Instagram?'**
  String get accLogOutTitle;

  /// S-13 log-out confirmation body (from UX.md S-13).
  ///
  /// In en, this message translates to:
  /// **'Stop all checks and remove the saved session? Your downloads and targets are kept.'**
  String get accLogOutBody;

  /// S-13 log-out confirmation button.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accLogOutConfirm;
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
