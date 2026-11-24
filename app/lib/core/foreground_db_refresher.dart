import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Re-runs the database watch queries. Null when not wired (tests).
///
/// Each isolate has its own database connection (see
/// `StorizeDatabase.open`), so rows written by the background check do not
/// notify the UI's watch queries by themselves.
final dbRefreshProvider = Provider<void Function()?>((ref) => null);

/// Refills the persisted page discovery of the logged-in account (T-045).
/// Null when not wired (tests, background). The callee decides whether a load
/// is due (at most once per 6 h per account, never while the governor is
/// paused); calling it often is cheap.
final discoveryRefreshProvider = Provider<Future<Object?> Function()?>(
  (ref) => null,
);

/// Calls [dbRefreshProvider] (and asks for a discovery refresh) when the app
/// comes back to the foreground and every [interval] while it stays there, so
/// background downloads appear.
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
    _refreshDiscovery();
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

  /// Asks for a discovery refresh: at app open and on every resume. Never
  /// awaited and never throws: a failed refresh waits for the next resume.
  void _refreshDiscovery() {
    try {
      final refresh = ref.read(discoveryRefreshProvider);
      if (refresh != null) {
        unawaited(refresh().then<void>((_) {}, onError: (Object _) {}));
      }
    } on Object {
      // Best effort.
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
      _refreshDiscovery();
      _start();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
