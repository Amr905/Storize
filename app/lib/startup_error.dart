import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Shown when the app cannot build its parts at start-up (database, secure
/// storage, notifications, ...). Before, a failure here fell back to an app
/// with nothing wired, so later screens failed with misleading errors
/// ("Login isn't available right now") or the dev tools stayed blank.
///
/// Dev builds show the error text and the top of the stack so a tester can
/// send a screenshot. Release builds show only the error type. Error texts
/// can contain app-private file paths but never cookies or tokens: nothing
/// secret is read before the composition exists.
class StartupErrorApp extends StatelessWidget {
  /// Creates the screen for [error].
  const StartupErrorApp({
    required this.error,
    this.stack,
    this.showDetails,
    super.key,
  });

  /// What went wrong.
  final Object error;

  /// Where it went wrong.
  final StackTrace? stack;

  /// Overrides the flavor check (tests). Null: details only in the dev flavor.
  final bool? showDetails;

  /// The text shown, capped so a huge message cannot freeze the screen.
  String details() {
    final message = error.toString();
    final head = message.length > 1500
        ? '${message.substring(0, 1500)}…'
        : message;
    final lines = (stack?.toString() ?? '').split('\n').take(25).join('\n');
    return 'type=${error.runtimeType}\n\n$head\n\n$lines'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final detailed = showDetails ?? appFlavor == 'dev';
    final text = detailed ? details() : 'type=${error.runtimeType}';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                "Storize couldn't start",
                key: ValueKey('startup-error-title'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please send a screenshot of this screen to the developer.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                text,
                key: const ValueKey('startup-error-details'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    unawaitedCopy(Clipboard.setData(ClipboardData(text: text))),
                child: const Text('Copy details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fire-and-forget for the copy button.
void unawaitedCopy(Future<void> f) => f.ignore();
