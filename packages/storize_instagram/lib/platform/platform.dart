/// Building blocks of `InstagramPlatform`: mode interfaces, transport choice,
/// persistent adapters (username cache, WebView lease, seen breaker) and the
/// signals the platform reports.
library;

export 'package:storize_instagram/page/seen_breaker_store.dart';

export 'extraction_ops.dart';
export 'governor_webview_lease.dart';
export 'platform_signals.dart';
export 'skip_counting_transport.dart';
export 'target_username_cache.dart';
export 'transport_selection.dart';
