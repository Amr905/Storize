// Golden tests (light + dark) for every design-system component.
// Fonts: see `loadTestFonts` in golden_helpers.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

import 'golden_helpers.dart';

void _noop() {}

Widget _gap([double h = 12]) => SizedBox(height: h);

Widget _tile(Widget child) => SizedBox(width: 68, child: child);

void main() {
  setUpAll(loadTestFonts);

  goldenBoth(
    'status_badge',
    (_) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in StorizeStatus.values) StatusBadge(status: s),
      ],
    ),
  );

  goldenBoth(
    'session_banner',
    (_) => Column(
      children: [
        const SessionBanner(kind: SessionBannerKind.needsRelogin, onFix: _noop),
        _gap(),
        const SessionBanner(kind: SessionBannerKind.restricted, onFix: _noop),
      ],
    ),
  );

  goldenBoth(
    'target_row',
    (_) => const Column(
      children: [
        TargetRow(
          username: 'nour_k',
          category: CategoryKind.ownClient,
          status: StorizeStatus.active,
          meta: 'Checked 10:12 - 3 new',
          onTap: _noop,
        ),
        TargetRow(
          username: 'brandx',
          category: CategoryKind.consented,
          status: StorizeStatus.needsRelogin,
          meta: 'Paused until login',
          onTap: _noop,
        ),
        TargetRow(
          username: 'client_co',
          category: CategoryKind.publicFigure,
          status: StorizeStatus.paused,
          onTap: _noop,
          swipeAction: TargetRowSwipeAction(
            label: 'Pause',
            icon: Icons.pause_rounded,
            onTriggered: _noop,
          ),
        ),
      ],
    ),
  );

  goldenBoth(
    'category_tag',
    (_) => const Wrap(
      spacing: 8,
      children: [
        CategoryTag(kind: CategoryKind.ownClient),
        CategoryTag(kind: CategoryKind.consented),
        CategoryTag(kind: CategoryKind.publicFigure),
      ],
    ),
  );

  goldenBoth(
    'story_thumb',
    (_) => Row(
      children: [
        _tile(
          StoryThumb(
            semanticLabel: 'photo',
            content: fakeMedia(Colors.orange, Colors.deepOrange),
            isNew: true,
          ),
        ),
        _tile(
          StoryThumb(
            semanticLabel: 'video',
            content: fakeMedia(Colors.indigo, Colors.blue),
            isVideo: true,
            duration: const Duration(seconds: 12),
            isNew: true,
          ),
        ),
        _tile(
          StoryThumb(
            semanticLabel: 'seen video',
            content: fakeMedia(Colors.teal, Colors.green),
            isVideo: true,
            duration: const Duration(seconds: 8),
          ),
        ),
        _tile(
          StoryThumb(
            semanticLabel: 'selected',
            content: fakeMedia(Colors.pink, Colors.purple),
            selected: true,
          ),
        ),
        _tile(
          StoryThumb(
            semanticLabel: 'selecting',
            content: fakeMedia(Colors.amber, Colors.brown),
            selectionMode: true,
          ),
        ),
        _tile(const StoryThumb(semanticLabel: 'broken', broken: true)),
      ],
    ),
    width: 480,
  );

  goldenBoth(
    'post_thumb',
    (_) => Row(
      children: [
        _tile(
          PostThumb(
            semanticLabel: 'photo',
            content: fakeMedia(Colors.orange, Colors.deepOrange),
          ),
        ),
        _tile(
          PostThumb(
            semanticLabel: 'carousel',
            content: fakeMedia(Colors.indigo, Colors.blue),
            carouselCount: 5,
            isNew: true,
          ),
        ),
        _tile(
          PostThumb(
            semanticLabel: 'video',
            content: fakeMedia(Colors.teal, Colors.green),
            isVideo: true,
            duration: const Duration(seconds: 30),
          ),
        ),
        _tile(
          PostThumb(
            semanticLabel: 'selected',
            content: fakeMedia(Colors.pink, Colors.purple),
            selected: true,
          ),
        ),
        _tile(
          PostThumb(
            semanticLabel: 'selecting',
            content: fakeMedia(Colors.amber, Colors.brown),
            selectionMode: true,
          ),
        ),
        _tile(const PostThumb(semanticLabel: 'broken', broken: true)),
      ],
    ),
    width: 480,
  );

  goldenBoth(
    'date_header',
    (_) => const Column(
      children: [
        DateHeader(label: 'Today'),
        DateHeader(label: 'Yesterday', trailing: Text('12')),
      ],
    ),
  );

  goldenBoth(
    'account_chip_row',
    (_) => Column(
      children: [
        AccountChipRow(
          items: const [
            AccountChipItem(id: 'a', label: '@nour_k'),
            AccountChipItem(id: 'b', label: '@brandx'),
            AccountChipItem(id: 'c', label: '@client_co'),
          ],
          selectedIds: const {},
          onChanged: (_) {},
        ),
        _gap(),
        AccountChipRow(
          items: const [
            AccountChipItem(id: 'a', label: '@nour_k'),
            AccountChipItem(id: 'b', label: '@brandx'),
            AccountChipItem(id: 'c', label: '@client_co'),
            AccountChipItem(id: 'd', label: '@d'),
            AccountChipItem(id: 'e', label: '@e'),
          ],
          selectedIds: const {'a', 'b'},
          multiSelect: true,
          maxVisible: 2,
          onChanged: (_) {},
          onOverflowTap: _noop,
        ),
      ],
    ),
  );

  goldenBoth(
    'stat_tile',
    (_) => const Row(
      children: [
        Expanded(
          child: StatTile(value: '128', label: 'Saved'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: StatTile(value: '3', label: 'New today'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: StatTile(value: '1.2 GB', label: 'Storage'),
        ),
      ],
    ),
  );

  goldenBoth(
    'step_card',
    (_) => Column(
      children: [
        const StepCard(
          number: 1,
          title: 'Turn off battery limits',
          body: 'Lets Storize check for new stories while the phone is idle.',
          actionLabel: 'Open settings',
          onAction: _noop,
        ),
        _gap(),
        const StepCard(
          number: 2,
          title: 'Allow notifications',
          body: 'Hidden when collapsed.',
          status: StepStatus.done,
          expandable: true,
          initiallyExpanded: false,
        ),
        _gap(),
        const StepCard(
          number: 3,
          title: 'Choose gallery folder',
          body: 'Expanded and done.',
          status: StepStatus.done,
          expandable: true,
          actionLabel: 'Change',
          onAction: _noop,
        ),
      ],
    ),
  );

  goldenBoth(
    'activity_item',
    (_) => const Column(
      children: [
        ActivityItem(
          icon: Icons.download_done_rounded,
          tone: ActivityTone.success,
          time: '10:15',
          text: '3 stories saved from @nour_k',
        ),
        ActivityItem(
          icon: Icons.sync_rounded,
          tone: ActivityTone.info,
          time: '10:12',
          text: 'Checking 12 accounts',
        ),
        ActivityItem(
          icon: Icons.warning_amber_rounded,
          tone: ActivityTone.warning,
          time: '09:40',
          text: 'Login needs attention',
          actionLabel: 'Fix',
          onAction: _noop,
        ),
        ActivityItem(
          icon: Icons.error_rounded,
          tone: ActivityTone.error,
          time: '09:02',
          text: 'Could not reach Instagram',
          actionLabel: 'Retry',
          onAction: _noop,
        ),
        ActivityItem(
          icon: Icons.pause_circle_rounded,
          tone: ActivityTone.neutral,
          time: 'Yesterday',
          text: '@brandx paused',
        ),
      ],
    ),
  );

  goldenBoth(
    'empty_state',
    (_) => const SizedBox(
      height: 320,
      child: EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Nothing saved yet',
        body: 'Add an account and Storize will save its stories automatically.',
        actionLabel: 'Add account',
        onAction: _noop,
      ),
    ),
  );

  goldenBoth(
    'skeleton',
    (_) => const Column(
      children: [
        SkeletonList(itemCount: 3, animate: false),
        SizedBox(height: 16),
        SkeletonGrid(itemCount: 3, animate: false),
      ],
    ),
  );

  goldenBoth(
    'confirm_dialog',
    (_) => const Column(
      children: [
        ConfirmDialog(
          title: 'Log out of Instagram?',
          body: 'Checks stop until you log in again.',
          confirmLabel: 'Log out',
          cancelLabel: 'Cancel',
        ),
        SizedBox(height: 12),
        ConfirmDialog(
          title: 'Delete 3 stories?',
          body: 'They are removed from your gallery too.',
          confirmLabel: 'Delete',
          cancelLabel: 'Cancel',
          destructive: true,
        ),
      ],
    ),
  );

  goldenBoth(
    'setting_row',
    (_) => Column(
      children: [
        const SettingRow.navigation(
          title: 'Instagram account',
          subtitle: 'Logged in as @storize_archive',
          leadingIcon: Icons.person_outline_rounded,
          onTap: _noop,
        ),
        SettingRow.toggle(
          title: 'Notifications',
          subtitle: 'Tell me about new stories',
          leadingIcon: Icons.notifications_none_rounded,
          switchValue: true,
          onChanged: (_) {},
        ),
        SettingRow.toggle(
          title: 'App lock',
          switchValue: false,
          onChanged: (_) {},
        ),
        const SettingRow.value(
          title: 'Check every',
          value: '30 min',
          onTap: _noop,
        ),
        const SettingRow.info(
          title: 'Version',
          subtitle: 'Storize 0.1.0 (1)',
          leadingIcon: Icons.info_outline_rounded,
        ),
      ],
    ),
  );

  goldenBoth(
    'buttons',
    (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PrimaryButton(label: 'Add account', onPressed: _noop),
            PrimaryButton(
              label: 'Add',
              icon: Icons.add_rounded,
              onPressed: _noop,
            ),
            PrimaryButton(label: 'Disabled', onPressed: null),
            PrimaryButton(
              label: 'Verifying...',
              loading: true,
              onPressed: _noop,
            ),
            PrimaryButton(label: 'Delete', destructive: true, onPressed: _noop),
          ],
        ),
        _gap(),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TonalButton(label: 'Tonal', onPressed: _noop),
            TonalButton(label: 'Working', loading: true, onPressed: _noop),
            TonalButton(label: 'Disabled', onPressed: null),
          ],
        ),
        _gap(),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StorizeTextButton(label: 'Text', onPressed: _noop),
            StorizeTextButton(
              label: 'Working',
              loading: true,
              onPressed: _noop,
            ),
            StorizeTextButton(
              label: 'Remove',
              destructive: true,
              onPressed: _noop,
            ),
          ],
        ),
        _gap(),
        const PrimaryButton(
          label: 'Full width',
          expand: true,
          onPressed: _noop,
        ),
      ],
    ),
  );

  goldenBoth(
    'pin_pad',
    (_) => Column(
      children: [
        PinPad(
          length: 4,
          filled: 2,
          onDigit: (_) {},
          onBackspace: _noop,
          onBiometric: _noop,
        ),
        _gap(24),
        PinPad(
          length: 6,
          filled: 6,
          errorText: 'Wrong PIN',
          onDigit: (_) {},
          onBackspace: _noop,
        ),
        _gap(24),
        PinPad(
          length: 4,
          filled: 0,
          cooldown: const Duration(seconds: 30),
          onDigit: (_) {},
          onBackspace: _noop,
        ),
      ],
    ),
  );

  goldenBoth(
    'kind_switch',
    (_) => Column(
      children: [
        KindSwitch(
          selected: LibraryKind.stories,
          storiesLabel: 'Stories',
          postsLabel: 'Posts',
          storiesCount: 12,
          postsCount: 3,
          onChanged: (_) {},
        ),
        _gap(),
        KindSwitch(
          selected: LibraryKind.posts,
          storiesLabel: 'Stories',
          postsLabel: 'Posts',
          storiesCount: 12,
          postsCount: 3,
          onChanged: (_) {},
        ),
      ],
    ),
  );
}
