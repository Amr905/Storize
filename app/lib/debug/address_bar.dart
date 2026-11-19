import 'package:material_ui/material_ui.dart';
import 'package:storize_app/debug/address.dart';

/// Minimal address bar: a text field plus Go. Only instagram.com URLs are
/// accepted; [onGo] gets the normalized URI.
class InspectorAddressBar extends StatefulWidget {
  /// Creates the bar.
  const InspectorAddressBar({required this.onGo, super.key});

  /// Called with a valid instagram.com URI.
  final ValueChanged<Uri> onGo;

  @override
  State<InspectorAddressBar> createState() => _InspectorAddressBarState();
}

class _InspectorAddressBarState extends State<InspectorAddressBar> {
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _go() {
    final uri = normalizeInspectorAddress(_text.text);
    setState(
      () => _error = uri == null ? 'Only instagram.com addresses' : null,
    );
    if (uri != null) widget.onGo(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: '/stories/<user>/  or  instagram.com/<user>/',
                errorText: _error,
                isDense: true,
              ),
              onSubmitted: (_) => _go(),
            ),
          ),
          TextButton(onPressed: _go, child: const Text('Go')),
        ],
      ),
    );
  }
}
