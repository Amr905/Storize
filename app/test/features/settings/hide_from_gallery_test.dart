import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import 'settings_rig.dart';

const _hint =
    'Only Storize shows your saved files. Uninstalling Storize deletes them.';

/// The rig plus the move wiring (FR-79).
class _Move {
  _Move(this.rig) {
    library = MoveLibrary(
      content: rig.content,
      gallery: rig.gallery,
      state: state,
      clock: rig.clock,
    );
  }

  final SettingsRig rig;
  final FakeMoveStateStore state = FakeMoveStateStore();
  final FakeMoveScheduler scheduler = FakeMoveScheduler();
  late final MoveLibrary library;

  List<Override> get overrides => [
    moveLibraryProvider.overrideWithValue(library),
    moveStateStoreProvider.overrideWithValue(state),
    moveSchedulerProvider.overrideWithValue(scheduler),
  ];

  /// Saves [n] files (one story each) into [target].
  Future<void> seed(int n, StorageTarget target) async {
    final t = await rig.addTarget('acct${rig.content.hashCode}');
    for (var i = 0; i < n; i++) {
      final f = await rig.gallery.save(
        sourcePath: 'none',
        relativeDir: 'acct',
        displayName: 'f$i.jpg',
        mime: 'image/jpeg',
        target: target,
      );
      await rig.content.insertIfNew(
        Content(
          id: Content.unsavedId,
          targetId: t.id,
          kind: ContentKind.story,
          remoteId: 's$i${target.name}',
          postedAt: rigNow,
          slideCount: 1,
          detectedAt: rigNow,
          status: ContentStatus.done,
        ),
        [
          MediaFile(
            id: MediaFile.unsavedId,
            contentId: Content.unsavedId,
            slideIndex: 0,
            mediaType: MediaType.photo,
            sourceUrl: 'https://cdn.example.test/$i',
            status: MediaFileStatus.done,
            contentUri: f.uri,
            relativePath: 'Pictures/Storize/acct/',
            displayName: 'f$i.jpg',
          ),
        ],
      );
    }
  }
}

/// Taps the switch and lets the async chain (setting write, file count) run.
Future<void> _toggle(WidgetTester t) async {
  await t.tap(_switch);
  await _letAsyncRun(t);
}

/// The fakes answer on the real event loop: give it a turn, then redraw.
Future<void> _letAsyncRun(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _scrollToToggle(WidgetTester t) async {
  await t.scrollUntilVisible(find.text('Hide from phone gallery'), 200);
  await t.pumpAndSettle();
}

Finder get _switch => find.descendant(
  of: find.widgetWithText(SwitchListTile, 'Hide from phone gallery'),
  matching: find.byType(Switch),
);

void main() {
  testWidgets('shows the switch with the uninstall warning, off by default', (
    t,
  ) async {
    final rig = SettingsRig();
    final move = _Move(rig);
    await pumpSettings(t, rig, extra: move.overrides);
    await _scrollToToggle(t);
    expect(find.text('Hide from phone gallery'), findsOneWidget);
    expect(find.text(_hint), findsOneWidget);
    expect(t.widget<Switch>(_switch).value, isFalse);
    expect(find.text('Saved to Pictures/Storize'), findsOneWidget);
  });

  testWidgets('turning it on with nothing saved just saves the setting', (
    t,
  ) async {
    final rig = SettingsRig();
    final move = _Move(rig);
    await pumpSettings(t, rig, extra: move.overrides);
    await _scrollToToggle(t);

    await _toggle(t);

    expect((await rig.settingsRepo.get()).hideFromGallery, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(move.scheduler.enqueued, isEmpty);
    expect(
      find.text('Saved privately, only Storize shows them'),
      findsOneWidget,
    );
  });

  testWidgets('on with saved files asks "Move N saved files now?"', (t) async {
    final rig = SettingsRig();
    final move = _Move(rig);
    await move.seed(3, StorageTarget.gallery);
    await pumpSettings(t, rig, extra: move.overrides);
    await _scrollToToggle(t);

    await _toggle(t);

    expect(find.text('Move 3 saved files now?'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Only new downloads'), findsOneWidget);
    // The setting already applies to new downloads.
    expect((await rig.settingsRepo.get()).hideFromGallery, isTrue);
  });

  testWidgets('"Only new downloads" moves nothing', (t) async {
    final rig = SettingsRig();
    final move = _Move(rig);
    await move.seed(2, StorageTarget.gallery);
    await pumpSettings(t, rig, extra: move.overrides);
    await _scrollToToggle(t);
    await _toggle(t);

    await t.tap(find.text('Only new downloads'));
    await _letAsyncRun(t);

    expect(move.scheduler.enqueued, isEmpty);
    expect(rig.gallery.galleryFiles, hasLength(2));
    expect((await rig.settingsRepo.get()).hideFromGallery, isTrue);
  });

  testWidgets('"Move" starts the background move and shows progress', (
    t,
  ) async {
    final rig = SettingsRig();
    final move = _Move(rig);
    await move.seed(3, StorageTarget.gallery);
    await pumpSettings(t, rig, extra: move.overrides);
    await _scrollToToggle(t);
    await _toggle(t);

    await t.tap(find.text('Move'));
    await _letAsyncRun(t);

    expect(move.scheduler.enqueued, [
      (target: StorageTarget.private, rollover: false),
    ]);
    expect(move.state.progress.status, MoveStatus.running);
    expect(move.state.progress.total, 3);
    expect(find.text('Moving files… 0 of 3'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    // Stop the 1 s polling timer.
    await move.state.write(MoveProgress.none);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('turning it off offers to move the private files back', (
    t,
  ) async {
    final rig = SettingsRig(settings: const AppSettings(hideFromGallery: true));
    final move = _Move(rig);
    await move.seed(2, StorageTarget.private);
    await pumpSettings(t, rig, extra: move.overrides);
    await _scrollToToggle(t);

    await _toggle(t);

    expect(
      find.text('Move 2 saved files back to the gallery?'),
      findsOneWidget,
    );
    await t.tap(find.text('Move'));
    await _letAsyncRun(t);
    expect(move.scheduler.enqueued, [
      (target: StorageTarget.gallery, rollover: false),
    ]);
    expect((await rig.settingsRepo.get()).hideFromGallery, isFalse);
    await move.state.write(MoveProgress.none);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('suggests App lock when hiding is on and the lock is off', (
    t,
  ) async {
    final rig = SettingsRig(settings: const AppSettings(hideFromGallery: true));
    await pumpSettings(t, rig, extra: _Move(rig).overrides);
    await _scrollToToggle(t);
    expect(
      find.text('Tip: turn on App lock so Storize is protected too.'),
      findsOneWidget,
    );
  });

  testWidgets('no lock tip when App lock is on, or when hiding is off', (
    t,
  ) async {
    final locked = SettingsRig(
      settings: const AppSettings(hideFromGallery: true, appLockEnabled: true),
    );
    await pumpSettings(t, locked, extra: _Move(locked).overrides);
    await _scrollToToggle(t);
    expect(find.textContaining('Tip: turn on App lock'), findsNothing);
  });

  testWidgets('no lock tip while hiding is off', (t) async {
    final rig = SettingsRig();
    await pumpSettings(t, rig, extra: _Move(rig).overrides);
    await _scrollToToggle(t);
    expect(find.textContaining('Tip: turn on App lock'), findsNothing);
  });

  group('the move row', () {
    Future<_Move> pumpWith(
      WidgetTester t,
      MoveProgress progress, {
      bool hide = true,
    }) async {
      final rig = SettingsRig(settings: AppSettings(hideFromGallery: hide));
      final move = _Move(rig)..state.progress = progress;
      await pumpSettings(t, rig, extra: move.overrides);
      await _scrollToToggle(t);
      return move;
    }

    MoveProgress running({int total = 10, int moved = 4, DateTime? at}) =>
        MoveProgress(
          status: MoveStatus.running,
          target: StorageTarget.private,
          total: total,
          moved: moved,
          updatedAt: at ?? rigNow,
        );

    testWidgets('running: count, bar and Cancel that stops the move', (
      t,
    ) async {
      final move = await pumpWith(t, running());
      expect(find.text('Moving files… 4 of 10'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await t.tap(find.text('Cancel'));
      await _letAsyncRun(t);

      expect(await move.state.cancelRequested(), isTrue);
      expect(move.scheduler.cancelCalls, 1);
      expect(move.state.progress.status, MoveStatus.cancelled);
      expect(find.text('Move stopped: 4 of 10 moved.'), findsOneWidget);
      await move.state.write(MoveProgress.none);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('a running move that stopped writing is "interrupted"', (
      t,
    ) async {
      final move = await pumpWith(
        t,
        running(at: rigNow.subtract(const Duration(minutes: 10))),
      );
      expect(find.text('Move interrupted: 4 of 10 moved.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await t.tap(find.text('Resume'));
      await _letAsyncRun(t);
      expect(move.scheduler.enqueued.single.target, StorageTarget.private);
      await move.state.write(MoveProgress.none);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('storage full says nothing was lost and offers Resume', (
      t,
    ) async {
      await pumpWith(
        t,
        MoveProgress(
          status: MoveStatus.storageFull,
          target: StorageTarget.private,
          total: 9,
          moved: 5,
          updatedAt: rigNow,
        ),
      );
      expect(
        find.text(
          'Not enough space: 5 of 9 moved. Free some space, then resume.',
        ),
        findsOneWidget,
      );
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('done shows the count, missing and failed, and OK clears it', (
      t,
    ) async {
      final move = await pumpWith(
        t,
        MoveProgress(
          status: MoveStatus.done,
          target: StorageTarget.private,
          total: 12,
          moved: 9,
          missing: 2,
          failed: 1,
          updatedAt: rigNow,
        ),
      );
      expect(find.text('9 files moved.'), findsOneWidget);
      expect(find.text('2 files were already missing.'), findsOneWidget);
      expect(
        find.text('1 file could not be moved and stays where it was.'),
        findsOneWidget,
      );
      // Failed files can be retried.
      expect(find.text('Resume'), findsOneWidget);

      await t.tap(find.text('OK'));
      await _letAsyncRun(t);
      expect(move.state.progress, MoveProgress.none);
      expect(find.text('9 files moved.'), findsNothing);
    });

    testWidgets('a clean finish has no Resume', (t) async {
      await pumpWith(
        t,
        MoveProgress(
          status: MoveStatus.done,
          target: StorageTarget.gallery,
          total: 3,
          moved: 3,
          updatedAt: rigNow,
        ),
      );
      expect(find.text('3 files moved.'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('idle shows no move row', (t) async {
      await pumpWith(t, MoveProgress.none);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('OK'), findsNothing);
    });
  });

  testWidgets('without the move wiring the switch still saves the setting', (
    t,
  ) async {
    final rig = SettingsRig();
    await pumpSettings(t, rig);
    await _scrollToToggle(t);
    await _toggle(t);
    expect((await rig.settingsRepo.get()).hideFromGallery, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('no file name, path or username is on screen', (t) async {
    final rig = SettingsRig(settings: const AppSettings(hideFromGallery: true));
    final move = _Move(rig);
    await move.seed(1, StorageTarget.private);
    await pumpSettings(t, rig, extra: move.overrides);
    await _scrollToToggle(t);
    expect(find.textContaining('file://'), findsNothing);
    expect(find.textContaining('f0.jpg'), findsNothing);
  });
}
