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

  /// No description provided for @bannerReloginTitle.
  ///
  /// In en, this message translates to:
  /// **'Instagram login needs attention'**
  String get bannerReloginTitle;

  /// No description provided for @bannerReloginBody.
  ///
  /// In en, this message translates to:
  /// **'Checks are paused.'**
  String get bannerReloginBody;

  /// No description provided for @bannerRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Instagram account restricted'**
  String get bannerRestrictedTitle;

  /// No description provided for @bannerRestrictedBody.
  ///
  /// In en, this message translates to:
  /// **'Checks are paused.'**
  String get bannerRestrictedBody;

  /// No description provided for @thumbNew.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get thumbNew;

  /// No description provided for @thumbBroken.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load'**
  String get thumbBroken;

  /// No description provided for @thumbSelected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get thumbSelected;

  /// No description provided for @stepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get stepDone;

  /// No description provided for @stepPending.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get stepPending;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @pinDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pinDelete;

  /// No description provided for @pinBiometric.
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
