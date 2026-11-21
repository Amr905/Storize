/// Which pages the S-02 login WebView may open (TECH_SPEC §5.1).
///
/// Only https pages on `instagram.com` or `facebook.com` (and their
/// subdomains, for the Facebook-login variant) may load. Every other
/// navigation is cancelled. `l.instagram.com` is Instagram's outbound link
/// redirector and is blocked too.
abstract final class LoginHostPolicy {
  /// The registrable domains that may load.
  static const List<String> allowedDomains = ['instagram.com', 'facebook.com'];

  /// Subdomains that are never allowed (outbound link redirector).
  static const Set<String> blockedHosts = {'l.instagram.com', 'l.facebook.com'};

  /// The page the login starts on.
  static final Uri loginUrl = Uri.parse(
    'https://www.instagram.com/accounts/login/',
  );

  /// Whether [url] may load in the login WebView.
  static bool allows(Uri url) {
    if (url.scheme != 'https') return false;
    final host = url.host.toLowerCase();
    if (host.isEmpty || blockedHosts.contains(host)) return false;
    return allowedDomains.any((d) => host == d || host.endsWith('.$d'));
  }

  /// Whether [url] is an Instagram page (where the session cookies live).
  static bool isInstagram(Uri url) {
    final host = url.host.toLowerCase();
    return url.scheme == 'https' &&
        (host == 'instagram.com' || host.endsWith('.instagram.com'));
  }
}
