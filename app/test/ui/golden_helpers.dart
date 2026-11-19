import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

/// Loads the real Roboto and Material icon fonts that ship inside the Flutter
/// SDK (`bin/cache/artifacts/material_fonts`) so goldens contain readable text
/// instead of Ahem boxes. It is the same file on every machine that has the
/// pinned Flutter SDK, so goldens are deterministic on Linux CI. If the SDK
/// font directory cannot be found, the default test font (Ahem) is used and
/// the goldens will not match the committed ones.
///
/// Goldens are generated and verified on Linux only. Regenerate with
/// `melos run golden:update` (or `flutter test --update-goldens` in `app/`).
Future<void> loadTestFonts() async {
  final dir = _materialFontsDir();
  if (dir == null) return;
  final roboto = FontLoader('Roboto');
  for (final file in const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final bytes = File('${dir.path}/$file').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('${dir.path}/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

Directory? _materialFontsDir() {
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
  ];
  // flutter_tester lives in <sdk>/bin/cache/artifacts/engine/<platform>/.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidates
      ..add('${dir.path}/material_fonts')
      ..add('${dir.path}/artifacts/material_fonts');
    dir = dir.parent;
  }
  for (final c in candidates) {
    if (File('$c/Roboto-Regular.ttf').existsSync()) return Directory(c);
  }
  return null;
}

/// Wraps [child] in the Storize theme and a Material shell.
Widget themed(
  Widget child, {
  required Brightness brightness,
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light
        ? StorizeTheme.light()
        : StorizeTheme.dark(),
    builder: (context, c) =>
        Directionality(textDirection: direction, child: c!),
    home: Scaffold(body: child),
  );
}

/// Registers a light and a dark golden test for [name]. The widget returned by
/// [build] is laid out in a [width]-dp wide surface-coloured box with 16 dp
/// padding, and only that box is compared against `goldens/<name>_<mode>.png`.
void goldenBoth(
  String name,
  Widget Function(BuildContext context) build, {
  double width = 400,
}) {
  for (final brightness in Brightness.values) {
    final mode = brightness.name;
    testWidgets('$name golden ($mode)', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(600, 3000);
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (context) => Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [build(context)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      // One frame only: spinners/pulses animate forever.
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/${name}_$mode.png'),
      );
    });
  }
}

/// A gradient standing in for real media.
Widget fakeMedia(Color a, Color b) => DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [a, b],
    ),
  ),
);
