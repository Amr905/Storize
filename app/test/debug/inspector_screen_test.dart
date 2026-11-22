import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/debug/hook_message.dart';
import 'package:storize_app/debug/inspector_log.dart';
import 'package:storize_app/debug/inspector_screen.dart';

void main() {
  testWidgets('builds with a fake WebView and lists captured responses', (
    tester,
  ) async {
    final log = InspectorLog();
    await tester.pumpWidget(
      MaterialApp(
        home: DebugInspectorScreen(
          log: log,
          loadHookSource: () async => '// fake hook',
          webViewBuilder: (context, log) =>
              const Center(child: Text('fake webview')),
        ),
      ),
    );
    expect(find.text('fake webview'), findsOneWidget);
    expect(find.text('No JSON responses captured yet.'), findsOneWidget);

    log.add(
      const CapturedResponse(
        url: 'https://www.instagram.com/api/v1/feed/reels_media/?x=1',
        status: 200,
        bodyLength: 99,
        topLevelKeys: ['reels', 'status'],
      ),
    );
    await tester.pump();
    expect(
      find.text('200  www.instagram.com/api/v1/feed/reels_media/'),
      findsOneWidget,
    );
    expect(find.textContaining('keys: reels, status'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear list'));
    await tester.pump();
    expect(find.text('No JSON responses captured yet.'), findsOneWidget);
  });

  testWidgets('without a builder on a non-Android platform shows a notice', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(home: DebugInspectorScreen(loadHookSource: () async => '')),
    );
    expect(find.text('WebView is only available on Android.'), findsOneWidget);
  });

  test('InspectorLog caps its size', () {
    final log = InspectorLog();
    for (var i = 0; i < InspectorLog.maxEntries + 5; i++) {
      log.add(
        CapturedResponse(
          url: 'https://www.instagram.com/a/$i',
          status: 200,
          bodyLength: i,
          topLevelKeys: const [],
        ),
      );
    }
    expect(log.entries, hasLength(InspectorLog.maxEntries));
    expect(log.entries.first.bodyLength, 5);
  });
}
