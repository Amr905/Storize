import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:storize_app/features/onboarding/login_host_policy.dart';
import 'package:storize_app/features/onboarding/login_web_view.dart';

/// The real login WebView, on `flutter_inappwebview`.
///
/// No JavaScript handler or user script is registered. Navigation goes through
/// [LoginHostPolicy]; everything else is cancelled.
Widget buildInAppLoginWebView(
  BuildContext context,
  LoginWebViewEvents events,
) => InAppWebView(
  initialUrlRequest: URLRequest(url: WebUri.uri(LoginHostPolicy.loginUrl)),
  initialSettings: InAppWebViewSettings(
    allowFileAccess: false,
    allowContentAccess: false,
  ),
  onWebViewCreated: (c) => events.onReady(_InAppController(c)),
  shouldOverrideUrlLoading: (_, action) async {
    final url = action.request.url?.uriValue;
    if (url != null && events.allowNavigation(url)) {
      return NavigationActionPolicy.ALLOW;
    }
    if (url != null) events.onBlocked(url);
    return NavigationActionPolicy.CANCEL;
  },
  onLoadStart: (_, url) {
    final u = url?.uriValue;
    if (u != null) events.onLoadStart(u);
  },
  onProgressChanged: (_, p) => events.onProgress(p),
  onLoadStop: (_, url) {
    final u = url?.uriValue;
    if (u != null) events.onLoadStop(u);
  },
  onReceivedError: (_, request, error) {
    if (request.isForMainFrame ?? true) {
      final offline =
          error.type == WebResourceErrorType.HOST_LOOKUP ||
          error.type == WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
          error.type == WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
          error.type == WebResourceErrorType.TIMEOUT;
      events.onLoadError(
        offline ? LoginLoadError.network : LoginLoadError.page,
      );
    }
  },
  onReceivedHttpError: (_, request, response) {
    if ((request.isForMainFrame ?? false) &&
        (response.statusCode ?? 0) >= 500) {
      events.onLoadError(LoginLoadError.page);
    }
  },
);

final class _InAppController implements LoginWebViewController {
  _InAppController(this._c);

  final InAppWebViewController _c;

  @override
  Future<Map<String, String>> readCookies() async {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri.uri(LoginHostPolicy.loginUrl),
      webViewController: _c,
    );
    return {for (final c in cookies) c.name: '${c.value}'};
  }

  @override
  Future<String?> userAgent() async {
    final settings = await _c.getSettings();
    return settings?.userAgent ??
        await InAppWebViewController.getDefaultUserAgent();
  }

  @override
  Future<void> clearData() async {
    await CookieManager.instance().deleteAllCookies();
    await _c.clearHistory();
    await _c.webStorage.localStorage.clear();
    await _c.webStorage.sessionStorage.clear();
    await InAppWebViewController.clearAllCache();
  }

  @override
  Future<void> reload() => _c.loadUrl(
    urlRequest: URLRequest(url: WebUri.uri(LoginHostPolicy.loginUrl)),
  );
}
