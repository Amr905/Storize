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
  /// **'Accounts'**
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
  /// **'Accounts'**
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

  /// Status of a completed permission step such as notifications.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get stepAllowed;

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

  /// Empty state title when there is nothing to show yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyNoDataTitle;

  /// Empty state body when there is nothing to show yet.
  ///
  /// In en, this message translates to:
  /// **'Items will show up here when there is something to see.'**
  String get emptyNoDataBody;

  /// Empty state title when the active filters hide every item.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get emptyFilteredTitle;

  /// Empty state body suggesting how to change the filters.
  ///
  /// In en, this message translates to:
  /// **'Try changing or clearing the filters.'**
  String get emptyFilteredBody;

  /// Error state title when the device is offline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetworkTitle;

  /// Error state body when the device is offline.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get errorNetworkBody;

  /// Error state title when Instagram limits requests.
  ///
  /// In en, this message translates to:
  /// **'Instagram is limiting requests'**
  String get errorRateLimitedTitle;

  /// Error state body when Instagram limits requests.
  ///
  /// In en, this message translates to:
  /// **'Storize will try again later.'**
  String get errorRateLimitedBody;

  /// Error state title when the Instagram pages changed and the app cannot read them.
  ///
  /// In en, this message translates to:
  /// **'Instagram changed'**
  String get errorPlatformChangedTitle;

  /// Error state body asking the user to update Storize.
  ///
  /// In en, this message translates to:
  /// **'Update Storize to keep saving content.'**
  String get errorPlatformChangedBody;

  /// Error state title for an unexpected failure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknownTitle;

  /// Error state body for an unexpected failure.
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

  /// S-14 line under the heading.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or PIN'**
  String get lockSubtitle;

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

  /// Library app bar: tooltip of the search button (FR-76).
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get libSearchTooltip;

  /// Library search field hint (FR-76).
  ///
  /// In en, this message translates to:
  /// **'Search username, caption or location'**
  String get libSearchHint;

  /// Tooltip of the button that clears the search text.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get libSearchClear;

  /// Tooltip of the back button that closes the search field.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get libSearchBack;

  /// Active filter chip for the search text. {query} is the text typed by the user.
  ///
  /// In en, this message translates to:
  /// **'Search: {query}'**
  String libSearchChip(String query);

  /// S-05 kind option and active filter chip: reels only (FR-76).
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get libKindReels;

  /// S-04 button that removes every active filter chip and the search.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get libClearAll;

  /// S-04 empty state (c) body when the search or filters hide every item.
  ///
  /// In en, this message translates to:
  /// **'Try fewer filters.'**
  String get libNoMatchesBody;

  /// S-04 line under the filter chips with the number of items shown (FR-76).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String libResultCount(int count);

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

  /// S-06 header: posted time and relative age.
  ///
  /// In en, this message translates to:
  /// **'Posted {time} · {ago}'**
  String storyPostedLine(String time, String ago);

  /// Relative age under one minute.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get storyAgoJustNow;

  /// Relative age in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} min ago}}'**
  String storyAgoMinutes(int count);

  /// Relative age in hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 h ago} other{{count} h ago}}'**
  String storyAgoHours(int count);

  /// Relative age in days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String storyAgoDays(int count);

  /// S-06 header: account handle.
  ///
  /// In en, this message translates to:
  /// **'@{username}'**
  String storyAccount(String username);

  /// S-06 close button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get storyClose;

  /// S-06 mute button tooltip (sound on).
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get storyMute;

  /// S-06 mute button tooltip (sound off).
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get storyUnmute;

  /// S-06 video play button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get storyPlay;

  /// S-06 video pause button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get storyPause;

  /// S-06 video scrubber semantics label.
  ///
  /// In en, this message translates to:
  /// **'Video position'**
  String get storyScrubber;

  /// S-06 spinner semantics label while a file or video prepares.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get storyLoading;

  /// S-06 link-sticker strip entry.
  ///
  /// In en, this message translates to:
  /// **'Link sticker: {url}'**
  String storyLinkSticker(String url);

  /// S-06 action bar: share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get storyShare;

  /// S-06 action bar: info sheet.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get storyInfo;

  /// S-06 action bar: delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get storyDelete;

  /// S-06 delete button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete (deletes from your gallery too)'**
  String get storyDeleteTooltip;

  /// S-06 delete confirmation title; same wording as the Library.
  ///
  /// In en, this message translates to:
  /// **'Delete 1 item?'**
  String get storyDeleteTitle;

  /// S-06 delete confirmation body; same wording as the Library.
  ///
  /// In en, this message translates to:
  /// **'They\'ll also be removed from your gallery. This can\'t be undone.'**
  String get storyDeleteBody;

  /// Cancel button on the S-06 confirm dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get storyCancel;

  /// Snackbar after a successful delete from S-06.
  ///
  /// In en, this message translates to:
  /// **'1 item deleted'**
  String get storyDeleted;

  /// Snackbar when a delete from S-06 fails.
  ///
  /// In en, this message translates to:
  /// **'This item couldn\'t be deleted.'**
  String get storyDeleteFailed;

  /// Snackbar when the item has no saved file to share.
  ///
  /// In en, this message translates to:
  /// **'Nothing to share yet. The file is still downloading.'**
  String get storyShareNothing;

  /// Snackbar when sharing fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share this item.'**
  String get storyShareFailed;

  /// S-06 missing-file state title (EC-20).
  ///
  /// In en, this message translates to:
  /// **'This file is missing'**
  String get storyMissingTitle;

  /// S-06 missing-file state confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Remove it from your library?'**
  String get storyMissingBody;

  /// S-06 missing-file state: remove action.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get storyRemoveFromLibrary;

  /// S-06 error state when the video cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be played.'**
  String get storyCantPlay;

  /// S-06 photo with no preview file.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get storyPhotoUnavailable;

  /// Title of the S-06 Info sheet.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get storyInfoTitle;

  /// Info sheet row: posted time.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get storyInfoPosted;

  /// Info sheet row: downloaded time.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get storyInfoDownloaded;

  /// Info sheet row: media type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get storyInfoType;

  /// Media type label: photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get storyTypePhoto;

  /// Media type label: video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get storyTypeVideo;

  /// Info sheet row: video length.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get storyInfoDuration;

  /// Info sheet row: file size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get storyInfoSize;

  /// File size under one megabyte.
  ///
  /// In en, this message translates to:
  /// **'{kilobytes} KB'**
  String storySizeKb(String kilobytes);

  /// File size of one megabyte or more.
  ///
  /// In en, this message translates to:
  /// **'{megabytes} MB'**
  String storySizeMb(String megabytes);

  /// Info sheet row: Instagram item ID.
  ///
  /// In en, this message translates to:
  /// **'Item ID'**
  String get storyInfoItemId;

  /// Info sheet row: gallery folder of the saved file.
  ///
  /// In en, this message translates to:
  /// **'Gallery folder'**
  String get storyInfoFolder;

  /// S-01 supporting line under the headline.
  ///
  /// In en, this message translates to:
  /// **'Storize saves the stories and posts of the accounts you choose, straight to your gallery, in the background.'**
  String get onbWelcomeTagline;

  /// S-01 risk card title.
  ///
  /// In en, this message translates to:
  /// **'Before you continue'**
  String get onbRiskTitle;

  /// S-01 risk bullet. Text between ** markers is rendered bold.
  ///
  /// In en, this message translates to:
  /// **'Storize uses an Instagram account to view stories. Instagram may **challenge or ban** that account.'**
  String get onbRisk1;

  /// S-01 risk bullet. Text between ** markers is rendered bold.
  ///
  /// In en, this message translates to:
  /// **'People you track will see that account **in their story viewers**.'**
  String get onbRisk2;

  /// S-01 risk bullet. Text between ** markers is rendered bold.
  ///
  /// In en, this message translates to:
  /// **'Use a **dedicated account**, not your personal one.'**
  String get onbRisk3;

  /// S-01 risk bullet. Text between ** markers is rendered bold.
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
  /// **'Checked {count} accounts'**
  String actCheckDoneOk(int count);

  /// S-11 second line of a clean check entry.
  ///
  /// In en, this message translates to:
  /// **'No errors'**
  String get actCheckDoneOkSub;

  /// S-11 second line of a check entry with failures.
  ///
  /// In en, this message translates to:
  /// **'{failed} failed'**
  String actCheckFailedSub(int failed);

  /// S-11 entry: a check finished with failed accounts.
  ///
  /// In en, this message translates to:
  /// **'Checked {count} accounts · {failed} failed'**
  String actCheckDoneFailed(int count, int failed);

  /// S-11 entry title: stories were downloaded (the account is the second line).
  ///
  /// In en, this message translates to:
  /// **'{count} stories downloaded'**
  String actDownloadedStories(int count);

  /// S-11 entry title: posts were downloaded (the account is the second line).
  ///
  /// In en, this message translates to:
  /// **'{count} posts downloaded'**
  String actDownloadedPosts(int count);

  /// S-11 info entry second line (EC-7): which account, and that it is not an error.
  ///
  /// In en, this message translates to:
  /// **'{account} · not an error'**
  String actRemovedBeforeDownload(String account);

  /// S-11 info entry title (EC-7).
  ///
  /// In en, this message translates to:
  /// **'Story removed before download'**
  String get actRemovedTitle;

  /// S-11 warning entry title with the time range.
  ///
  /// In en, this message translates to:
  /// **'Gap: no checks from {from} to {to}'**
  String actGapTitle(String from, String to);

  /// S-11 gap entry second line.
  ///
  /// In en, this message translates to:
  /// **'Android may have stopped Storize'**
  String get actGapSub;

  /// S-11 warning entry title: no checks ran during the time range shown on the second line.
  ///
  /// In en, this message translates to:
  /// **'Gap: no checks'**
  String get actGap;

  /// Semantics label of the account chip that stands for the accounts hidden behind it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more account} other{{count} more accounts}}'**
  String a11yMoreAccounts(int count);

  /// S-11 gap entry second line: the time range without checks.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to}'**
  String actGapRange(String from, String to);

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
  /// **'Instagram slowed us down'**
  String get actRateLimited;

  /// S-11 rate-limit entry second line.
  ///
  /// In en, this message translates to:
  /// **'Checks were slowed down to be safe'**
  String get actRateLimitedSub;

  /// S-11 error entry (EC-1/2); opens S-13.
  ///
  /// In en, this message translates to:
  /// **'Instagram login needs attention'**
  String get actSessionProblem;

  /// S-11 session entry second line.
  ///
  /// In en, this message translates to:
  /// **'Checks are paused until you log in again'**
  String get actSessionProblemSub;

  /// S-11 error entry (EC-14).
  ///
  /// In en, this message translates to:
  /// **'Instagram changed — update Storize'**
  String get actPlatformChanged;

  /// S-11 platform-changed entry second line.
  ///
  /// In en, this message translates to:
  /// **'Checks may fail until the app is updated'**
  String get actPlatformChangedSub;

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
  /// **'Downloads paused'**
  String get actStoragePaused;

  /// S-11 storage-paused entry second line.
  ///
  /// In en, this message translates to:
  /// **'Storage is full'**
  String get actStoragePausedSub;

  /// S-11 info entry title: a tracked account changed status (the account is the second line).
  ///
  /// In en, this message translates to:
  /// **'Account status changed'**
  String get actTargetStatus;

  /// S-11 warning entry title: a saved file is gone from the gallery (the account is the second line).
  ///
  /// In en, this message translates to:
  /// **'File missing from gallery'**
  String get actFileMissing;

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

  /// Targets title with the tracked count and the recommended limit (S-07).
  ///
  /// In en, this message translates to:
  /// **'{count} of {limit} recommended'**
  String tgtCountLimit(int count, int limit);

  /// Category name on S-07, S-08, S-09 (design wording).
  ///
  /// In en, this message translates to:
  /// **'Own / Client'**
  String get tgtCatOwn;

  /// S-08 category option title.
  ///
  /// In en, this message translates to:
  /// **'Own / Client account'**
  String get tgtCatOwnTitle;

  /// S-08 helper line under the own/client category.
  ///
  /// In en, this message translates to:
  /// **'Accounts you or your clients own'**
  String get tgtCatOwnHint;

  /// Category name on S-07, S-08, S-09 (design wording).
  ///
  /// In en, this message translates to:
  /// **'Person who agreed'**
  String get tgtCatConsented;

  /// S-08 helper line under the consented category.
  ///
  /// In en, this message translates to:
  /// **'They know and consented to archiving'**
  String get tgtCatConsentedHint;

  /// S-08 category name.
  ///
  /// In en, this message translates to:
  /// **'Public creator / brand'**
  String get tgtCatPublic;

  /// S-07, S-09 short category tag.
  ///
  /// In en, this message translates to:
  /// **'Public creator'**
  String get tgtCatPublicShort;

  /// S-08 helper line under the public category.
  ///
  /// In en, this message translates to:
  /// **'Public account'**
  String get tgtCatPublicHint;

  /// S-08 inline error when the request budget is used up; the form stays editable.
  ///
  /// In en, this message translates to:
  /// **'Instagram limit reached — try again in about {minutes} min'**
  String tgtErrRateLimited(int minutes);

  /// S-07 extended floating button label.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tgtAddShort;

  /// S-07 row meta, number of saved items.
  ///
  /// In en, this message translates to:
  /// **'{count} saved'**
  String tgtMetaSaved(int count);

  /// S-07 row note for a paused target.
  ///
  /// In en, this message translates to:
  /// **'Paused by you'**
  String get tgtMetaPausedByYou;

  /// S-07 row note for a target that is not visible.
  ///
  /// In en, this message translates to:
  /// **'Private — not followed'**
  String get tgtMetaPrivate;

  /// S-07 row note for an unavailable target.
  ///
  /// In en, this message translates to:
  /// **'Account no longer exists'**
  String get tgtMetaGone;

  /// S-07 action: check all active targets now (FR-21).
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get tgtCheckNow;

  /// Tooltip on the disabled Check now action (BR-7).
  ///
  /// In en, this message translates to:
  /// **'Log in again to check now.'**
  String get tgtCheckNowDisabled;

  /// Snackbar after Check now.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing new} =1{1 new item} other{{count} new items}}'**
  String tgtCheckDone(int count);

  /// Dev builds only: overflow menu item on S-07 that runs a check without the hourly request limit.
  ///
  /// In en, this message translates to:
  /// **'Check now (debug, no limit)'**
  String get debugCheckNowUnmetered;

  /// Snackbar when Check now fails.
  ///
  /// In en, this message translates to:
  /// **'The check could not run.'**
  String get tgtCheckFailed;

  /// Warning bar on S-07 while checks are slowed (EC-15).
  ///
  /// In en, this message translates to:
  /// **'Instagram is limiting requests. Storize has slowed checks down.'**
  String get tgtRateLimitBar;

  /// S-07 row meta line: last check time.
  ///
  /// In en, this message translates to:
  /// **'Checked {time}'**
  String tgtMetaChecked(String time);

  /// S-07 row meta line when a target was never checked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get tgtMetaNever;

  /// S-07 row meta line: last new story time.
  ///
  /// In en, this message translates to:
  /// **'Last new {time}'**
  String tgtMetaLastNew(String time);

  /// Joins two meta parts on S-07.
  ///
  /// In en, this message translates to:
  /// **'{first} · {second}'**
  String tgtMetaLine(String first, String second);

  /// Swipe action on a target row.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get tgtActionPause;

  /// Swipe action on a paused target row.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get tgtActionResume;

  /// Snackbar when pausing or resuming fails.
  ///
  /// In en, this message translates to:
  /// **'The change could not be saved.'**
  String get tgtUpdateFailed;

  /// S-07 empty state title.
  ///
  /// In en, this message translates to:
  /// **'Track your first account'**
  String get tgtEmptyTitle;

  /// S-07 empty state body.
  ///
  /// In en, this message translates to:
  /// **'Add an Instagram account to start saving its stories and posts.'**
  String get tgtEmptyBody;

  /// S-07 add button (FAB) label and empty-state action.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get tgtAddAccount;

  /// S-08 title.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get tgtFormTitle;

  /// S-08 close icon semantics label.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get tgtClose;

  /// S-08 username field label.
  ///
  /// In en, this message translates to:
  /// **'Username or profile link'**
  String get tgtUsernameLabel;

  /// S-08 username field hint.
  ///
  /// In en, this message translates to:
  /// **'@username or instagram.com/name'**
  String get tgtUsernameHint;

  /// S-08 inline username error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Instagram username or profile link.'**
  String get tgtUsernameInvalid;

  /// S-08 category group label; * marks it required.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get tgtCategoryLabel;

  /// S-08 category error on submit (BR-1).
  ///
  /// In en, this message translates to:
  /// **'Choose a category.'**
  String get tgtCategoryRequired;

  /// S-08 track chips group label.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get tgtTrackLabel;

  /// S-08 track chip.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get tgtTrackStories;

  /// S-08 track chip.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get tgtTrackPosts;

  /// S-08 track chip.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get tgtTrackReels;

  /// S-08 error when every track chip is off (FR-65, FR-67).
  ///
  /// In en, this message translates to:
  /// **'Choose at least one.'**
  String get tgtTrackRequired;

  /// S-08 hint under the track chips (FR-63, A-18).
  ///
  /// In en, this message translates to:
  /// **'Today\'s posts and stories are saved now. Pick a post history below for older posts.'**
  String get tgtTrackHint;

  /// S-08 note field label.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get tgtNoteLabel;

  /// S-08 note field hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. consent by email 3/11'**
  String get tgtNoteHint;

  /// S-08 error when the note is too long (FR-16).
  ///
  /// In en, this message translates to:
  /// **'Keep the note to 200 characters or fewer.'**
  String get tgtNoteTooLong;

  /// S-08 inline error: account does not exist.
  ///
  /// In en, this message translates to:
  /// **'No Instagram account named {username}.'**
  String tgtNotFound(String username);

  /// S-08 inline error: private and not followed (BR-2).
  ///
  /// In en, this message translates to:
  /// **'{username} is private and {login} doesn\'t follow it. Follow it first from Instagram.'**
  String tgtNotVisiblePrivate(String username, String login);

  /// S-08 inline error: the account blocked the login.
  ///
  /// In en, this message translates to:
  /// **'{username} can\'t be seen from the logged-in account.'**
  String tgtNotVisibleBlocked(String username);

  /// S-08 inline error: duplicate by user ID (EC-16, EC-5).
  ///
  /// In en, this message translates to:
  /// **'Already tracked as {username}.'**
  String tgtDuplicate(String username);

  /// S-08 action on the duplicate error: opens S-09.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get tgtOpen;

  /// S-08 session warning; the Add button is disabled (BR-7).
  ///
  /// In en, this message translates to:
  /// **'Log in again to add accounts.'**
  String get tgtSessionInactive;

  /// S-08 snackbar when the login account is restricted (EC-6).
  ///
  /// In en, this message translates to:
  /// **'Instagram restricted the login account. Checks are paused.'**
  String get tgtRestricted;

  /// S-08 non-blocking warning at the recommended limit (A-12, NFR-4).
  ///
  /// In en, this message translates to:
  /// **'More than {limit} accounts increases the risk of a ban.'**
  String tgtOverLimit(int limit);

  /// S-08 submit button.
  ///
  /// In en, this message translates to:
  /// **'Add & verify'**
  String get tgtAddAndVerify;

  /// S-08 button label while verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get tgtVerifying;

  /// S-08 snackbar after a successful add.
  ///
  /// In en, this message translates to:
  /// **'Tracking {username}. First check running…'**
  String tgtAdded(String username);

  /// S-08 snackbar when the account was saved as waiting because Instagram is limited or unreachable (FR-73).
  ///
  /// In en, this message translates to:
  /// **'Added. Instagram asked us to slow down, so we\'ll look up @{username} in a few minutes.'**
  String tgtAddedPending(String username);

  /// S-07 row chip for a target that is saved but not looked up yet (FR-73).
  ///
  /// In en, this message translates to:
  /// **'Waiting to look up'**
  String get tgtStatusPending;

  /// S-09 chip and status card text for a target that is saved but not looked up yet (FR-73).
  ///
  /// In en, this message translates to:
  /// **'Waiting to look up'**
  String get tdtStatusPending;

  /// S-15 type label: single photo post.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get postTypePhoto;

  /// S-15 type label: single video post.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get postTypeVideo;

  /// S-15 type label: carousel post.
  ///
  /// In en, this message translates to:
  /// **'Carousel'**
  String get postTypeCarousel;

  /// S-15 type label: reel.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get postTypeReel;

  /// S-15 top bar: slide counter.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String postCounter(int current, int total);

  /// S-15 semantics label for the media pager.
  ///
  /// In en, this message translates to:
  /// **'Slide {current} of {total}'**
  String postSlideSemantics(int current, int total);

  /// S-15 overflow menu tooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get postMoreTooltip;

  /// S-15 overflow menu: share every slide of the post.
  ///
  /// In en, this message translates to:
  /// **'Share all slides'**
  String get postShareAll;

  /// S-15 meta line: posted date and time, then the type label.
  ///
  /// In en, this message translates to:
  /// **'Posted {when} · {type}'**
  String postPostedOn(String when, String type);

  /// S-15 caption toggle: expand the caption.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get postCaptionMore;

  /// S-15 caption toggle: collapse the caption.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get postCaptionLess;

  /// S-15 Info sheet: label for the post link.
  ///
  /// In en, this message translates to:
  /// **'Post link'**
  String get postLinkTitle;

  /// S-15 Info sheet: copy the post link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get postCopyLink;

  /// S-15 snackbar after the post link is copied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get postLinkCopied;

  /// S-15 Info sheet row: slide count.
  ///
  /// In en, this message translates to:
  /// **'Slides'**
  String get postInfoSlides;

  /// S-15 Info sheet: number of slides.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 slide} other{{count} slides}}'**
  String postInfoSlideCount(int count);

  /// S-15 delete confirmation title; the count is the number of gallery files.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete this post (1 file)?} other{Delete this post ({count} files)?}}'**
  String postDeleteTitle(int count);

  /// S-15 delete confirmation body (gallery wording).
  ///
  /// In en, this message translates to:
  /// **'Also removes them from your gallery. This can\'t be undone.'**
  String get postDeleteBody;

  /// S-15 snackbar after the post is deleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postDeleted;

  /// S-15 snackbar when the delete fails.
  ///
  /// In en, this message translates to:
  /// **'This post couldn\'t be deleted.'**
  String get postDeleteFailed;

  /// S-15 per-slide state: the gallery file is gone (EC-20).
  ///
  /// In en, this message translates to:
  /// **'This slide\'s file is missing'**
  String get postSlideMissingTitle;

  /// S-15 per-slide missing state: explanation.
  ///
  /// In en, this message translates to:
  /// **'It was moved or deleted outside Storize.'**
  String get postSlideMissingBody;

  /// S-15 per-slide missing state: remove this slide from the library.
  ///
  /// In en, this message translates to:
  /// **'Remove slide'**
  String get postRemoveSlide;

  /// S-15 snackbar when removing one slide fails.
  ///
  /// In en, this message translates to:
  /// **'This slide couldn\'t be removed.'**
  String get postSlideRemoveFailed;

  /// S-15 per-slide state: the slide never finished downloading (EC-21).
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get postSlideNotDownloaded;

  /// S-15 per-slide not-downloaded state: explanation.
  ///
  /// In en, this message translates to:
  /// **'This slide didn\'t finish downloading.'**
  String get postSlideNotDownloadedBody;

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

  /// S-12 second line under Wi-Fi only.
  ///
  /// In en, this message translates to:
  /// **'Pause downloads on mobile data'**
  String get setWifiOnlyHint;

  /// S-12 second line under Keep Storize running.
  ///
  /// In en, this message translates to:
  /// **'Battery & background setup'**
  String get setKeepRunningHint;

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

  /// S-13 health row label.
  ///
  /// In en, this message translates to:
  /// **'Last successful check'**
  String get accLastCheckLabel;

  /// S-13 health row label.
  ///
  /// In en, this message translates to:
  /// **'Rate-limit events (7 days)'**
  String get accRateLimitLabel;

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
  /// **'Instagram ended the session or asked to confirm it\'s you. All checks are paused.'**
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

  /// S-09 overflow menu button tooltip.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get tdtMenuTooltip;

  /// S-09 overflow menu item that opens S-10.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tdtRemove;

  /// S-09 shown when the target ID does not exist.
  ///
  /// In en, this message translates to:
  /// **'This account is no longer tracked.'**
  String get tdtNotFound;

  /// S-09 category row label and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get tdtCategoryLabel;

  /// S-09 note row label and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get tdtNoteLabel;

  /// S-09 note row when the note is empty.
  ///
  /// In en, this message translates to:
  /// **'No note yet.'**
  String get tdtNoteNone;

  /// S-09 icon button tooltip for the category row.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get tdtEditCategory;

  /// S-09 icon button tooltip for the note row.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get tdtEditNote;

  /// S-09 stats tile label: saved stories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get tdtStatStories;

  /// S-09 stats tile label: saved posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get tdtStatPosts;

  /// S-09 stats tile label: stored bytes.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get tdtStatSpace;

  /// S-09 status card for a not-visible target.
  ///
  /// In en, this message translates to:
  /// **'This account is private and {login} doesn\'t follow it (or blocked it). Past downloads are kept.'**
  String tdtStatusNotVisible(String login);

  /// S-09 status card for an unavailable target.
  ///
  /// In en, this message translates to:
  /// **'This account no longer exists.'**
  String get tdtStatusUnavailable;

  /// S-09 status card for an error: the last error text and its time.
  ///
  /// In en, this message translates to:
  /// **'{error} ({time})'**
  String tdtStatusErrorBody(String error, String time);

  /// S-09 status card for an error without a reason.
  ///
  /// In en, this message translates to:
  /// **'The last check failed.'**
  String get tdtStatusErrorNone;

  /// Replaces @login in the not-visible text when the login account is unknown.
  ///
  /// In en, this message translates to:
  /// **'your account'**
  String get tdtLoginFallback;

  /// S-09 meta line: date of the newest post.
  ///
  /// In en, this message translates to:
  /// **'Last new post {date}'**
  String tdtMetaNewPost(String date);

  /// S-09 recent section title.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get tdtRecentLabel;

  /// S-09 link to S-04 filtered to this account.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get tdtSeeAll;

  /// S-09 recent empty state, stories.
  ///
  /// In en, this message translates to:
  /// **'No stories saved yet.'**
  String get tdtEmptyStories;

  /// S-09 recent empty state, posts.
  ///
  /// In en, this message translates to:
  /// **'No posts saved yet.'**
  String get tdtEmptyPosts;

  /// S-10 dialog title.
  ///
  /// In en, this message translates to:
  /// **'Stop tracking {username}?'**
  String tdtRemoveTitle(String username);

  /// S-10 dialog counts line.
  ///
  /// In en, this message translates to:
  /// **'{stories} stories and {posts} posts are saved for this account.'**
  String tdtRemoveCounts(int stories, int posts);

  /// S-10 option, default and safe choice.
  ///
  /// In en, this message translates to:
  /// **'Keep downloads'**
  String get tdtRemoveKeep;

  /// S-10 option that deletes the saved files.
  ///
  /// In en, this message translates to:
  /// **'Delete downloads too'**
  String get tdtRemoveDelete;

  /// S-10 second line under the keep option.
  ///
  /// In en, this message translates to:
  /// **'They stay in your Library and gallery'**
  String get tdtRemoveKeepHint;

  /// S-10 second line under the delete option.
  ///
  /// In en, this message translates to:
  /// **'Also removes them from your gallery. Can\'t be undone'**
  String get tdtRemoveDeleteHint;

  /// S-10 confirm button when delete is selected.
  ///
  /// In en, this message translates to:
  /// **'Remove & delete'**
  String get tdtRemoveConfirmDelete;

  /// S-07 snackbar after removal.
  ///
  /// In en, this message translates to:
  /// **'Stopped tracking {username}.'**
  String tdtRemoved(String username);

  /// S-10 error when some files could not be deleted.
  ///
  /// In en, this message translates to:
  /// **'Some downloads could not be deleted. Try again.'**
  String get tdtRemovePartial;

  /// S-10 error when removal failed.
  ///
  /// In en, this message translates to:
  /// **'The account could not be removed.'**
  String get tdtRemoveFailed;

  /// Notification channel name for new stories (T-022).
  ///
  /// In en, this message translates to:
  /// **'New stories'**
  String get ntfChannelNewStories;

  /// Notification channel name for new posts (T-022).
  ///
  /// In en, this message translates to:
  /// **'New posts'**
  String get ntfChannelNewPosts;

  /// Notification channel name for login alerts (T-022).
  ///
  /// In en, this message translates to:
  /// **'Login problems'**
  String get ntfChannelLoginProblems;

  /// Notification channel name for storage alerts (T-022).
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get ntfChannelStorage;

  /// Silent notification channel name for check progress (T-022).
  ///
  /// In en, this message translates to:
  /// **'Background checks'**
  String get ntfChannelBackground;

  /// Notification channel name for exports (T-022).
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get ntfChannelExport;

  /// Grouped notification text for one target's new stories (UX system notifications).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new story from @{username}} other{{count} new stories from @{username}}}'**
  String ntfStoriesFromAccount(int count, String username);

  /// Grouped notification text for one target's new posts (UX system notifications).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new post from @{username}} other{{count} new posts from @{username}}}'**
  String ntfPostsFromAccount(int count, String username);

  /// Group summary for new stories over several targets (EC-8).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new story} other{{count} new stories}} from {accounts, plural, one{1 account} other{{accounts} accounts}}'**
  String ntfStoriesSummary(int count, int accounts);

  /// Group summary for new posts over several targets (EC-8).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new post} other{{count} new posts}} from {accounts, plural, one{1 account} other{{accounts} accounts}}'**
  String ntfPostsSummary(int count, int accounts);

  /// High-priority login alert (UX system notifications).
  ///
  /// In en, this message translates to:
  /// **'Instagram login needs attention — checks are paused'**
  String get ntfLoginNeeded;

  /// High-priority storage alert (UX system notifications).
  ///
  /// In en, this message translates to:
  /// **'Storage almost full — downloads paused'**
  String get ntfStorageFull;

  /// Silent background notification while checks run (UX system notifications).
  ///
  /// In en, this message translates to:
  /// **'Checking {accounts, plural, one{1 account} other{{accounts} accounts}}…'**
  String ntfChecking(int accounts);

  /// S-08 label for the post history picker (FR-68).
  ///
  /// In en, this message translates to:
  /// **'Post history'**
  String get tgtHistoryLabel;

  /// S-08 and S-09 history range: no history (default).
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get tgtHistoryNone;

  /// S-08 and S-09 history range: posts from today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tgtHistoryToday;

  /// S-08 and S-09 history range: the last 7 days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get tgtHistory7Days;

  /// S-08 and S-09 history range: the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get tgtHistory30Days;

  /// S-08 and S-09 history range: opens a date picker.
  ///
  /// In en, this message translates to:
  /// **'Since a date…'**
  String get tgtHistorySince;

  /// S-08 and S-09 history range once a date is chosen.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String tgtHistorySinceDate(String date);

  /// S-08 and S-09 history range: every post.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tgtHistoryAll;

  /// S-08 hint shown when the history range is All.
  ///
  /// In en, this message translates to:
  /// **'Large accounts can take many hours; downloads run slowly in the background'**
  String get tgtHistoryAllHint;

  /// S-08 switch label: download the account's highlights (FR-71).
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get tgtHighlightsLabel;

  /// S-08 hint under the Highlights switch.
  ///
  /// In en, this message translates to:
  /// **'Saves the highlights now and the new items added to them later.'**
  String get tgtHighlightsHint;

  /// S-09 section title for post history (FR-68).
  ///
  /// In en, this message translates to:
  /// **'Post history'**
  String get tdtHistoryTitle;

  /// S-09 line showing the history range.
  ///
  /// In en, this message translates to:
  /// **'Range: {range}'**
  String tdtHistoryRange(String range);

  /// S-09 button that opens the history range picker.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get tdtHistoryChange;

  /// S-09 progress while the history downloads (FR-69). date is the oldest post seen so far.
  ///
  /// In en, this message translates to:
  /// **'Downloading history: {count, plural, =1{1 post} other{{count} posts}} so far · up to {date}'**
  String tdtHistoryRunning(int count, String date);

  /// S-09 progress before any post date is known.
  ///
  /// In en, this message translates to:
  /// **'Downloading history: {count, plural, =1{1 post} other{{count} posts}} so far'**
  String tdtHistoryRunningNoDate(int count);

  /// S-09 history state: paused (FR-69).
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get tdtHistoryPaused;

  /// S-09 history state: finished.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tdtHistoryDone;

  /// S-09 history state: stopped by an error; resume retries.
  ///
  /// In en, this message translates to:
  /// **'Stopped by an error. Resume history to try again.'**
  String get tdtHistoryFailed;

  /// S-09 button: pause the history download.
  ///
  /// In en, this message translates to:
  /// **'Pause history'**
  String get tdtHistoryPause;

  /// S-09 button: resume the history download.
  ///
  /// In en, this message translates to:
  /// **'Resume history'**
  String get tdtHistoryResume;

  /// S-09 button: stop the history download for good; stored posts stay.
  ///
  /// In en, this message translates to:
  /// **'Stop history'**
  String get tdtHistoryCancel;

  /// S-09 switch label: download the account's highlights (FR-71).
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get tdtHighlightsLabel;

  /// S-09 hint under the Highlights switch.
  ///
  /// In en, this message translates to:
  /// **'Saves all pinned stories in the background, then new ones.'**
  String get tdtHighlightsHint;

  /// S-05 filter chip: show only highlight items (FR-72).
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get libHighlightsFilter;

  /// S-06 header line naming the highlight of a highlight item (FR-72).
  ///
  /// In en, this message translates to:
  /// **'Highlight: {title}'**
  String storyHighlightTitle(String title);

  /// Preview screen title (FR-74).
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get prvTitle;

  /// S-08 button next to Add: opens the profile preview (FR-74).
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get prvPreviewButton;

  /// S-09 action that opens the profile preview of this account (FR-74).
  ///
  /// In en, this message translates to:
  /// **'Preview & save'**
  String get prvPreviewAction;

  /// Badge on the preview header of a private account.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get prvPrivateBadge;

  /// Preview section title: the stories live now.
  ///
  /// In en, this message translates to:
  /// **'Current stories'**
  String get prvCurrentStories;

  /// Preview section title: the first page of posts.
  ///
  /// In en, this message translates to:
  /// **'Recent posts'**
  String get prvRecentPosts;

  /// Preview: the account has no current story.
  ///
  /// In en, this message translates to:
  /// **'No stories right now.'**
  String get prvNoStories;

  /// Preview: the account has no posts on its first page.
  ///
  /// In en, this message translates to:
  /// **'No posts to show.'**
  String get prvNoPosts;

  /// Preview: semantic label of the select checkbox of one thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Select item'**
  String get prvSelectItem;

  /// Preview: semantic label of the check badge on a saved item.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get prvSavedBadge;

  /// Preview bottom bar: save the selected items.
  ///
  /// In en, this message translates to:
  /// **'Save selected ({count})'**
  String prvSaveSelected(int count);

  /// Preview bottom bar: save every item that is not saved yet.
  ///
  /// In en, this message translates to:
  /// **'Save all'**
  String get prvSaveAll;

  /// Preview bottom bar label while the files are downloaded.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get prvSaving;

  /// Preview: opens the add form with the username filled in, to track the account.
  ///
  /// In en, this message translates to:
  /// **'Track this account automatically'**
  String get prvTrack;

  /// Preview: shown instead of the Track button once the account is tracked.
  ///
  /// In en, this message translates to:
  /// **'Tracking is on for this account.'**
  String get prvTracking;

  /// Preview snackbar after a save.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved 1 item to your gallery} other{Saved {count} items to your gallery}}'**
  String prvSaveDone(int count);

  /// Preview snackbar when some items could not be saved.
  ///
  /// In en, this message translates to:
  /// **'Saved {saved}, {failed} failed'**
  String prvSavePartial(int saved, int failed);

  /// Preview snackbar when every chosen item was saved before.
  ///
  /// In en, this message translates to:
  /// **'Already saved.'**
  String get prvSaveAlready;

  /// Preview snackbar when nothing could be saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {reason}'**
  String prvSaveFailed(String reason);

  /// Preview: save failure reason, used inside the sentence of prvSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'another download is running, try again in a moment'**
  String get prvReasonBusy;

  /// Preview: save failure reason, used inside the sentence of prvSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'the phone is low on space'**
  String get prvReasonStorage;

  /// Preview: save failure reason, used inside the sentence of prvSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Storize can\'t write to the gallery'**
  String get prvReasonPermission;

  /// Preview: save failure reason, used inside the sentence of prvSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'log in again'**
  String get prvReasonSession;

  /// Preview: save failure reason, used inside the sentence of prvSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'the download failed'**
  String get prvReasonGeneric;

  /// Preview: the account cannot be shown.
  ///
  /// In en, this message translates to:
  /// **'This account is private or can\'t be seen from the logged-in account.'**
  String get prvNotVisible;

  /// Saffron badge on a library segment: how many items are new.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String kindSwitchNewBadge(int count);

  /// Library kind switch: highlights segment.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get libHighlightsTab;

  /// Saffron badge on a highlight thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get libHighlightBadge;

  /// S-12 section header for the theme choice.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get setSectionAppearance;

  /// S-12 appearance segment: follow the phone setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get setThemeSystem;

  /// S-12 appearance segment: always light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get setThemeLight;

  /// S-12 appearance segment: always dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get setThemeDark;

  /// S-12 hint under the appearance control.
  ///
  /// In en, this message translates to:
  /// **'System follows your phone\'s light or dark setting.'**
  String get setThemeHint;

  /// Screen reader label of the appearance segmented control.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get setThemeSemantics;

  /// S-01 headline.
  ///
  /// In en, this message translates to:
  /// **'Stories disappear.\nYours don\'t have to.'**
  String get onbWelcomeHeadline;

  /// S-01 promise row title.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get onbPromiseAutoTitle;

  /// S-01 promise row text.
  ///
  /// In en, this message translates to:
  /// **'New stories and posts are saved as they appear.'**
  String get onbPromiseAutoBody;

  /// S-01 promise row title.
  ///
  /// In en, this message translates to:
  /// **'Only who you choose'**
  String get onbPromiseChooseTitle;

  /// S-01 promise row text.
  ///
  /// In en, this message translates to:
  /// **'Storize saves the accounts you add, nothing else.'**
  String get onbPromiseChooseBody;

  /// S-01 promise row title.
  ///
  /// In en, this message translates to:
  /// **'Stays on your phone'**
  String get onbPromisePrivateTitle;

  /// S-01 promise row text.
  ///
  /// In en, this message translates to:
  /// **'No servers. Your login never leaves the device.'**
  String get onbPromisePrivateBody;

  /// S-09 heading above the saved stories and posts grid.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get tdtSavedTitle;

  /// S-06 chip over the media: the saved file's gallery folder.
  ///
  /// In en, this message translates to:
  /// **'In your gallery · Pictures/Storize/{username}'**
  String storyInGallery(String username);

  /// Info sheet: label above the post caption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get infoCaption;

  /// Info sheet: button that copies the caption to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy caption'**
  String get infoCopyCaption;

  /// Snackbar after the caption was copied (Info sheet button or long-press in the post viewer).
  ///
  /// In en, this message translates to:
  /// **'Caption copied'**
  String get infoCaptionCopied;

  /// Info sheet: accessibility label of the location pin icon.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get infoLocation;

  /// Info sheet: label above the chips of accounts tagged in the post.
  ///
  /// In en, this message translates to:
  /// **'Tagged accounts'**
  String get infoTagged;

  /// Info sheet row: when the file was saved to the gallery.
  ///
  /// In en, this message translates to:
  /// **'Saved on'**
  String get infoSavedOn;
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
