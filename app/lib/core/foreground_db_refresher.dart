import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Re-runs the database watch queries. Null when not wired (tests).
///
/// Each isolate has its own database connection (see
/// `StorizeDatabase.open`), so rows written by the background check do not
/// notify the UI's watch queries by themselves.
final dbRefreshProvider = Provider<void Function()?>((ref) => null);

/// Calls [dbRefreshProvider] when the app comes back to the foreground and
/// every [interval] while it stays there, so background downloads appear.
class ForegroundDbRefresher extends ConsumerStatefulWidget {
  /// Wraps [child].
  const ForegroundDbRefresher({
    required this.child,
    this.interval = const Duration(seconds: 15),
    super.key,
  });

  /// The app.
  final Widget child;

  /// How often to refresh while resumed.
  final Duration interval;

  @override
  ConsumerState<ForegroundDbRefresher> createState() =>
      _ForegroundDbRefresherState();
}

class _ForegroundDbRefresherState extends ConsumerState<ForegroundDbRefresher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    try {
      ref.read(dbRefreshProvider)?.call();
    } on Object {
      // A refresh is best effort; the next one tries again.
    }
  }

  void _start() {
    _timer?.cancel();
    if (ref.read(dbRefreshProvider) == null) return;
    _timer = Timer.periodic(widget.interval, (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _start();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
