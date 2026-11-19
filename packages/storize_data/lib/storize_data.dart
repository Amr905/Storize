/// Storize data layer (drift, settings, vault, gallery, logs).
///
/// Sub-barrels are owned by their tasks; this file is wired by the Lead.
library;

export 'db/db.dart';
export 'security/security.dart';
export 'settings/settings.dart';

/// Package version marker.
const String storizeDataVersion = '0.1.0';
