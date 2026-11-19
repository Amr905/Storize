import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/debug/hook_message.dart';
import 'package:storize_app/debug/inspector_log.dart';

/// Name of the JS handler that `hook.js` posts to.
const String hookHandlerName = 'storizeHook';

/// Asset path of the shared hook (declared in `storize_instagram`).
const String hookAssetPath = 'packages/storize_instagram/assets/hook.js';

/// Builds the WebView area. Receives the log to feed.
typedef InspectorWebViewBuilder = Widget Function(
  BuildContext context,
  InspectorLog log,
);

/// Loads the hook script text. Overridable in tests.
typedef HookSourceLoader = Future<String> Function();

Future<String> _loadHookFromAssets() => rootBundle.loadString(hookAssetPath);

/// Debug-only screen: Instagram in a WebView plus a live list of the JSON
/// responses that the injected hook saw. The user logs in by hand.
class DebugInspectorScreen extends StatefulWidget {
  /// Creates the screen. [webViewBuilder] defaults to a real WebView.
  const DebugInspectorScreen({
    super.key,
    this.log,
    this.webViewBuilder,
    this.loadHookSource = _loadHookFromAssets,
  });

  /// Optional log (tests inject one).
  final InspectorLog? log;

  /// Replaces the WebView (tests, unsupported platforms).
  final InspectorWebViewBuilder? webViewBuilder;

  /// Source of the hook JS.
  final HookSourceLoader loadHookSource;

  @override
  State<DebugInspectorScreen> createState() => _DebugInspectorScreenState();
}

class _DebugInspectorScreenState extends State<DebugInspectorScreen> {
  late final InspectorLog _log = widget.log ?? InspectorLog();
  late final Future<String> _hookSource = widget.loadHookSource();

  @override
  void dispose() {
    if (widget.log == null) _log.dispose();
    super.dispose();
  }

  Widget _defaultWebView(BuildContext context) {
    // Guard the platform view: only Android has a real WebView here.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Center(child: Text('WebView is only available on Android.'));
    }
    return FutureBuilder<String>(
      future: _hookSource,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load hook.js: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _InspectorWebView(hookSource: snap.data!, log: _log);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final web =
        widget.webViewBuilder?.call(context, _log) ?? _defaultWebView(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instagram inspector (debug)'),
        actions: [
          IconButton(
            tooltip: 'Clear list',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _log.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(flex: 3, child: web),
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: ListenableBuilder(
              listenable: _log,
              builder: (context, _) {
                final items = _log.entries.reversed.toList();
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No JSON responses captured yet.'),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final r = items[i];
                    return ListTile(
                      dense: true,
                      title: Text('${r.status}  ${r.shortUrl}'),
                      subtitle: Text(
                        '${r.bodyLength} chars  '
                        'keys: ${r.topLevelKeys.join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorWebView extends StatelessWidget {
  const _InspectorWebView({required this.hookSource, required this.log});

  final String hookSource;
  final InspectorLog log;

  @override
  Widget build(BuildContext context) {
    final script = UserScript(
      source:
          "window.__STORIZE_HOOK_CONFIG = {handler: '$hookHandlerName', "
          'includeBody: false};\n$hookSource',
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      allowedOriginRules: {allowedHookOrigin},
    );
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$allowedHookOrigin/')),
      initialUserScripts: UnmodifiableListView([script]),
      initialSettings: InAppWebViewSettings(
        allowFileAccess: false,
        allowContentAccess: false,
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: hookHandlerName,
          callback: (args) async {
            // Origin of the page as the native side sees it, not as the
            // page claims.
            final url = await controller.getUrl();
            final pageOrigin = url == null ? '' : '${url.scheme}://${url.host}';
            final parsed = parseHookMessage(args, pageOrigin: pageOrigin);
            if (parsed != null) log.add(parsed);
            return null;
          },
        );
      },
    );
  }
}
