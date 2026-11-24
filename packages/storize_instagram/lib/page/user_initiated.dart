import 'dart:async';

/// The zone key of a user-initiated run ("Check now").
const Object userInitiatedZoneKey = #storizeUserInitiatedRun;

/// Whether the code running now was started by the user (T-048). A manual
/// "Check now" runs in the background isolate, where page mode is off unless
/// the setting allows it; a user-initiated run may still load pages, a
/// scheduled one may not.
bool get isUserInitiatedRun => Zone.current[userInitiatedZoneKey] == true;

/// Runs [body] as a user-initiated run: every page load made inside it, also
/// after an `await`, is allowed in the background.
Future<T> runUserInitiated<T>(Future<T> Function() body) => runZoned(
  body,
  zoneValues: {userInitiatedZoneKey: true},
);
