/// Storize data layer (drift, settings, vault, gallery, logs).
///
/// Sub-barrels are owned by their tasks; this file is wired by the Lead.
library;

export 'db/db.dart';
export 'files/files.dart';
export 'log/log.dart';
export 'repo/repo.dart';
export 'security/security.dart';
export 'settings/settings.dart';
export 'update/update.dart';

/// Package version marker.
const String storizeDataVersion = '0.1.0';
