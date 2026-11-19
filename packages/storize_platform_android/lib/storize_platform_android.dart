/// Storize native Android plugin (MediaStore, OEM intents, thumbnails).
library;

import 'package:flutter/services.dart';

/// Package version marker.
const String storizePlatformAndroidVersion = '0.1.0';

/// Name of the placeholder media channel (implemented natively in T-009).
const String storizeMediaChannelName = 'storize/media';

/// Placeholder media channel; the native handler returns `notImplemented`.
const MethodChannel storizeMediaChannel = MethodChannel(
  storizeMediaChannelName,
);
