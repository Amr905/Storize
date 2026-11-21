import 'package:flutter/widgets.dart';

/// Why the login page failed to load.
enum LoginLoadError {
  /// The device is offline or the host was unreachable.
  network,

  /// Any other load failure (HTTP or TLS error).
  page,
}

/// Commands the login flow sends to the embedded WebView.
///
/// Implementations never expose cookie values to anything but the caller of
/// [readCookies] and never log them.
abstract interface class LoginWebViewController {
  /// The cookies of instagram.com, name to value. Values are secret.
  Future<Map<String, String>> readCookies();

  /// The WebView's user agent, or null when unknown.
  Future<String?> userAgent();

  /// Deletes every cookie and all web storage of the WebView.
  Future<void> clearData();

  /// Loads the login page again.
  Future<void> reload();
}

/// What the WebView reports back to the login flow. No JavaScript handler is
/// involved: these are native navigation callbacks only.
abstract interface class LoginWebViewEvents {
  /// Called when the controller exists.
  void onReady(LoginWebViewController controller);

  /// Decides a navigation. False cancels it.
  bool allowNavigation(Uri url);

  /// A navigation was cancelled by the allowlist.
  void onBlocked(Uri url);

  /// A page started loading.
  void onLoadStart(Uri url);

  /// Load progress, 0 to 100.
  void onProgress(int percent);

  /// A page finished loading.
  void onLoadStop(Uri url);

  /// A page failed to load.
  void onLoadError(LoginLoadError error);
}

/// Builds the login WebView widget (the real one, or a fake in tests).
typedef LoginWebViewBuilder = Widget Function(
  BuildContext context,
  LoginWebViewEvents events,
);
