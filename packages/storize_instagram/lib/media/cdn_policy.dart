/// Instagram CDN domains a media URL may point to (the T-013 rule of
/// `IgProbe.checkCdn`, repeated here because that helper is private).
const List<String> cdnDomains = ['cdninstagram.com', 'fbcdn.net'];

/// The URL as a [Uri] when it may be fetched without cookies, otherwise null.
///
/// The rule (same as T-013): scheme `https`, no user info, no port other than
/// 443, and a host that is a CDN domain or a sub-domain of one. Anything else
/// (another host, `http`, `blob:`, an IP address, a look-alike such as
/// `fbcdn.net.evil.test`) is refused and never requested.
Uri? allowedCdnUri(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return null;
  }
  if (uri.hasPort && uri.port != 443) return null;
  final host = uri.host.toLowerCase();
  final ok = cdnDomains.any((d) => host == d || host.endsWith('.$d'));
  return ok ? uri : null;
}
