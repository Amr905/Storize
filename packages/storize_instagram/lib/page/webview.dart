/// The real `flutter_inappwebview` adapter of page mode. Not exported by
/// `page.dart`: the app wiring (T-015, T-021) imports this library, and
/// unit tests of the extractor never do. Verified on device (T-014 AC9).
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:storize_instagram/page/dom_fallback.dart';
import 'package:storize_instagram/page/hook_protocol.dart';
import 'package:storize_instagram/page/inpage_script.dart';
import 'package:storize_instagram/page/page_driver.dart';

/// Where `hook.js` is bundled.
const String hookAssetPath = 'packages/storize_instagram/assets/hook.js';

/// Loads the content of `hook.js` from the asset bundle. In a background
/// isolate the Flutter binding must be initialised first.
Future<String> loadHookSource() => rootBundle.loadString(hookAssetPath);

/// Where `inpage_query.js` is bundled (T-050).
const String inPageAssetPath =
    'packages/storize_instagram/assets/inpage_query.js';

/// Loads the content of `inpage_query.js` from the asset bundle.
Future<String> loadInPageSource() => rootBundle.loadString(inPageAssetPath);

/// Anchored patterns for `javaScriptHandlersOriginAllowList`: exactly the two
/// instagram origins of `allowedPageOrigins`.
const Set<String> pageHandlerOriginPatterns = {
  r'^https://www\.instagram\.com$',
  r'^https://instagram\.com$',
};

/// A [PageDriver] over `HeadlessInAppWebView`.
///
/// The cookie jar of the WebView is global to the app: this driver wipes it
/// before it sets the session cookies and again when the session is cleared,
/// so no page-mode cookie survives a run. It must not run while the login
/// WebView of S-02 is open: `PageExtractor` takes the `WebViewLease` first.
///
/// Fails closed (QA-F5): without `WebViewFeature.DOCUMENT_START_SCRIPT` the
/// plugin injects the hook after the page has started, a race the story
/// "seen" mutation can win. `open` then throws
/// `PageHookUnsupportedException` before it touches cookies or loads anything.
final class InAppPageDriver implements PageDriver {
  /// Creates the driver. `documentStartSupported` is replaceable for tests of
  /// the decision; the default asks the WebView.
  const InAppPageDriver({
    this._documentStartSupported = _webViewHasDocumentStart,
  });

  final Future<bool> Function() _documentStartSupported;

  static final WebUri _siteUrl = WebUri('https://www.instagram.com/');

  @override
  Future<PageSession> open(PageSessionConfig config) async {
    var supported = false;
    try {
      supported = await _documentStartSupported();
    } on Object {
      supported = false;
    }
    if (!supported) throw const PageHookUnsupportedException();
    await _wipe();
    try {
      final cookies = CookieManager.instance();
      for (final entry in config.cookies.entries) {
        await cookies.setCookie(
          url: _siteUrl,
          name: entry.key,
          value: entry.value,
          domain: '.instagram.com',
          isSecure: true,
        );
      }
      final session = _InAppPageSession(config);
      await session.start();
      return session;
    } on Object {
      await _wipe();
      rethrow;
    }
  }
}

Future<bool> _webViewHasDocumentStart() =>
    WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT);

Future<void> _wipe() async {
  await CookieManager.instance().deleteAllCookies();
  await WebStorageManager.instance().deleteAllData();
  await InAppWebViewController.clearAllCache();
}

/// Pixels per scroll step: a few screens, so the list's loader fires.
const int _scrollStep = 4000;

final class _InAppPageSession implements PageSession, InPageScriptRunner {
  _InAppPageSession(this._config);

  final PageSessionConfig _config;
  final StreamController<PageEvent> _events = StreamController<PageEvent>();
  HeadlessInAppWebView? _view;
  InAppWebViewController? _controller;

  @override
  Stream<PageEvent> get events => _events.stream;

  void _emit(PageEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _navigated(WebUri? url) {
    if (url == null) return;
    _emit(NavigationEvent(host: url.host, path: url.path));
  }

  Future<void> start() async {
    final created = Completer<void>();
    final script = UserScript(
      source: _config.hookSource,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      allowedOriginRules: _config.allowedOrigins,
    );
    final view = HeadlessInAppWebView(
      initialUserScripts: UnmodifiableListView([script]),
      initialSettings: InAppWebViewSettings(
        userAgent: _config.userAgent,
        allowFileAccess: false,
        allowContentAccess: false,
        // The plugin bridge computes the frame origin inside the frame, so
        // the same rule is also enforced natively (QA-F4): only the two
        // instagram origins, only the main frame, may call the handler.
        javaScriptHandlersOriginAllowList: pageHandlerOriginPatterns,
        javaScriptHandlersForMainFrameOnly: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: _config.handlerName,
          callback: (JavaScriptHandlerFunctionData data) {
            // Origin of the frame that posted. On Android the plugin bridge
            // computes it in the frame (not independent of the page), so
            // `javaScriptHandlersOriginAllowList` repeats the check natively.
            final o = data.origin;
            _emit(
              HookEvent(
                pageOrigin: originOf(o.scheme, o.host, o.port),
                args: data.args,
              ),
            );
            return null;
          },
        );
        if (!created.isCompleted) created.complete();
      },
      onLoadStart: (controller, url) => _navigated(url),
      onUpdateVisitedHistory: (controller, url, isReload) => _navigated(url),
      onLoadStop: (controller, url) => _emit(const LoadStopEvent()),
      onReceivedHttpError: (controller, request, response) {
        final status = response.statusCode;
        if ((request.isForMainFrame ?? false) && status != null) {
          _emit(HttpErrorEvent(status));
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? false) _emit(const LoadErrorEvent());
      },
    );
    _view = view;
    await view.run();
    await created.future;
  }

  @override
  Future<void> load(Uri url) async {
    final controller = _controller;
    if (controller == null) throw StateError('not started');
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(url)));
  }

  @override
  Future<Object?> collectDomMedia() async {
    final controller = _controller;
    if (controller == null) return null;
    return controller.evaluateJavascript(source: domCollectScript);
  }

  @override
  Future<Object?> callAsync(
    String functionBody,
    Map<String, Object?> arguments,
  ) async {
    final controller = _controller;
    if (controller == null) throw StateError('not started');
    final result = await controller.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: arguments,
      // The page's own world: it has `window.require` and the tokens.
      contentWorld: ContentWorld.PAGE,
    );
    if (result == null || result.error != null) {
      throw StateError('script_failed');
    }
    return result.value;
  }

  @override
  Future<void> scrollDown() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.scrollBy(x: 0, y: _scrollStep);
  }

  @override
  Future<void> clearData() => _wipe();

  @override
  Future<void> dispose() async {
    await _events.close();
    await _view?.dispose();
    _view = null;
    _controller = null;
  }
}
