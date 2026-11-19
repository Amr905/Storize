import 'package:storize_app/debug/hook_message.dart';

/// Turns what the user typed into an https instagram.com URL, or null.
///
/// Accepts `/stories/x/`, `www.instagram.com/x/`, `instagram.com/x/` and full
/// `https://www.instagram.com/...` URLs. Anything on another host (or another
/// scheme) is rejected, so the inspector never leaves Instagram.
Uri? normalizeInspectorAddress(String input) {
  final t = input.trim();
  if (t.isEmpty || t.contains(RegExp(r'\s'))) return null;
  final String full;
  if (t.startsWith('/')) {
    full = '$allowedHookOrigin$t';
  } else if (t.startsWith('https://')) {
    full = t;
  } else if (t.contains('://')) {
    return null;
  } else {
    full = 'https://$t';
  }
  final uri = Uri.tryParse(full);
  if (uri == null || uri.scheme != 'https' || uri.hasPort) return null;
  if (uri.userInfo.isNotEmpty) return null;
  final host = uri.host;
  if (host != 'instagram.com' && !host.endsWith('.instagram.com')) {
    return null;
  }
  return uri;
}
