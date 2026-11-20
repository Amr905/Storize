/// The WebView seen through a small interface (AC2).
///
/// The extractor logic (parsing, timeout, origin checks, blocking counts,
/// failure map) is tested against fakes of these types. The real adapter is
/// `webview.dart`, which tests do not import.
library;

/// Something that happened in the page. `toString` of every event hides
/// payloads, paths and URLs: they can carry ids or signed values.
sealed class PageEvent {
  const PageEvent();
}

/// A message posted by `hook.js`. [pageOrigin] is the origin of the frame as
/// reported by the native side, not by the page.
final class HookEvent extends PageEvent {
  /// Creates the event.
  const HookEvent({required this.pageOrigin, required this.args});

  /// `scheme://host` of the posting frame (native side).
  final String pageOrigin;

  /// The handler arguments (the payload is `args.first`).
  final List<Object?> args;

  @override
  String toString() => 'HookEvent';
}

/// The main frame navigated to [host] and [path] (no query, no fragment).
final class NavigationEvent extends PageEvent {
  /// Creates the event.
  const NavigationEvent({required this.host, required this.path});

  /// The host.
  final String host;

  /// The path.
  final String path;

  @override
  String toString() => 'NavigationEvent';
}

/// The main document answered with an HTTP error [status].
final class HttpErrorEvent extends PageEvent {
  /// Creates the event.
  const HttpErrorEvent(this.status);

  /// The status code.
  final int status;

  @override
  String toString() => 'HttpErrorEvent($status)';
}

/// The main frame could not load (no network, DNS, TLS).
final class LoadErrorEvent extends PageEvent {
  /// Creates the event.
  const LoadErrorEvent();

  @override
  String toString() => 'LoadErrorEvent';
}

/// The main frame finished loading.
final class LoadStopEvent extends PageEvent {
  /// Creates the event.
  const LoadStopEvent();

  @override
  String toString() => 'LoadStopEvent';
}

/// Everything a driver needs to open one session. Holds secrets.
final class PageSessionConfig {
  /// Creates the config.
  const PageSessionConfig({
    required this.cookies,
    required this.userAgent,
    required this.hookSource,
    required this.handlerName,
    required this.allowedOrigins,
  });

  /// Cookie name to value; set on `.instagram.com`. Secret.
  final Map<String, String> cookies;

  /// The stored WebView User-Agent.
  final String userAgent;

  /// The user script: config prelude plus `hook.js`.
  final String hookSource;

  /// The JS handler name the hook posts to.
  final String handlerName;

  /// The origins the user script may run on.
  final Set<String> allowedOrigins;

  @override
  String toString() => 'PageSessionConfig(cookies: ${cookies.length})';
}

/// Opens page sessions.
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class PageDriver {
  /// Opens a session with the cookies set and the hook installed. Must leave
  /// no cookies behind if it throws.
  Future<PageSession> open(PageSessionConfig config);
}

/// One headless page. The extractor drives it and always disposes it.
abstract interface class PageSession {
  /// Events of the page. Listen before [load].
  Stream<PageEvent> get events;

  /// Starts loading [url] (does not wait for the page).
  Future<void> load(Uri url);

  /// LAST RESORT: runs the read-only DOM script (`domCollectScript`) and
  /// returns its result. Never clicks or scrolls.
  Future<Object?> collectDomMedia();

  /// Removes cookies, web storage and cache. Called in a `finally`.
  Future<void> clearData();

  /// Destroys the WebView.
  Future<void> dispose();
}
