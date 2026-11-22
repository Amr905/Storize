import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:storize_app/debug/tools/dev_tools_actions.dart';
import 'package:storize_domain/storize_domain.dart';

/// Developer-only screen for the phone test checklist (T-037a). Plain English
/// on purpose: it is never part of a release build.
class DevToolsScreen extends StatefulWidget {
  /// Creates the screen.
  const DevToolsScreen({required this.actions, super.key});

  /// The actions.
  final DevToolsActions actions;

  @override
  State<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends State<DevToolsScreen> {
  final _count = TextEditingController(
    text: '${DevToolsActions.defaultSeedCount}',
  );
  List<Target> _targets = const [];
  Target? _target;
  String _output = '';
  bool _busy = false;

  DevToolsActions get _a => widget.actions;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTargets());
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    final all = await _a.targets.watchAll().first;
    if (!mounted) return;
    setState(() {
      _targets = [
        for (final t in all)
          if (t.remoteUserId != DevToolsActions.seedTargetRemoteId) t,
      ];
      _target = _targets.isEmpty ? null : _targets.first;
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final text = await action();
    if (!mounted) return;
    setState(() {
      _output = text;
      _busy = false;
    });
  }

  Future<void> _withTarget(Future<String> Function(Target) action) async {
    final t = _target;
    if (t == null) {
      setState(() => _output = 'no target selected');
      return;
    }
    await _run(() => action(t));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storize dev tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButton<Target>(
            isExpanded: true,
            value: _target,
            hint: const Text('Target'),
            items: [
              for (final t in _targets)
                DropdownMenuItem(value: t, child: Text('@${t.username}')),
            ],
            onChanged: (t) => setState(() => _target = t),
          ),
          _button('Run check now (background)', () => _run(_a.runCheckNow)),
          _button(
            'Page-mode story load',
            () => _withTarget(_a.loadStoriesInPageMode),
          ),
          _button('Cookie count', () => _run(_a.countCookies)),
          _button('Probe + CDN check', () => _withTarget(_a.runProbe)),
          TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Seed rows'),
          ),
          _button(
            'Seed library',
            () => _run(
              () => _a.seedLibrary(
                int.tryParse(_count.text) ?? DevToolsActions.defaultSeedCount,
              ),
            ),
          ),
          _button('Clear seed', () => _run(_a.clearSeed)),
          _button('Recent log (50)', () => _run(_log)),
          const Divider(),
          if (_busy) const LinearProgressIndicator(),
          SelectableText(_output),
        ],
      ),
    );
  }

  Future<String> _log() async => (await _a.recentLog()).join('\n');

  Widget _button(String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: FilledButton(
      onPressed: _busy ? null : onPressed,
      child: Text(label),
    ),
  );
}
