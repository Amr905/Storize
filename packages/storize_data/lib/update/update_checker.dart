/// Update check against the GitHub Releases API (TECH_SPEC §4.2, NFR-9, ADR-8).
///
/// The check is silent: every failure resolves to [UpdateState.none] and
/// nothing is installed by the app itself.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

/// GitHub endpoint for the latest published release of Storize.
const String latestReleaseUrl =
    'https://api.github.com/repos/Amr905/Storize/releases/latest';

final RegExp _numericRe = RegExp(r'^\d+$');
final RegExp _identifiersRe = RegExp(r'^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$');
const String _releasePathPrefix = '/Amr905/Storize/releases/';
final RegExp _sha256Re = RegExp(r'^[0-9a-fA-F]{64}$');

/// A semantic version `MAJOR.MINOR.PATCH[-pre-release][+build]`.
///
/// Accepted input: an optional leading `v` or `V`, then exactly three numeric
/// core parts, then optional pre-release and build suffixes. Surrounding
/// whitespace is ignored.
///
/// Comparison rules:
/// - The numeric core is compared part by part (`1.10.0 > 1.9.9`).
/// - Build metadata (after `+`) is ignored, so `1.2.3+a` equals `1.2.3`.
/// - A pre-release sorts below the same core without one
///   (`1.2.3-beta` before `1.2.3`).
/// - Pre-release identifiers are compared dot by dot. Numeric identifiers
///   compare numerically and sort before alphanumeric ones; a shorter list
///   sorts first when it is a prefix of the longer one.
final class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion._(this.major, this.minor, this.patch, this.prerelease);

  /// Major version number.
  final int major;

  /// Minor version number.
  final int minor;

  /// Patch version number.
  final int patch;

  /// Dot-separated pre-release identifiers; empty for a release version.
  final List<String> prerelease;

  /// Parses [input], returning `null` when it is not a valid version.
  static SemanticVersion? tryParse(String input) {
    var s = input.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }

    // Build metadata is everything after the first '+'.
    final plus = s.indexOf('+');
    String? build;
    if (plus >= 0) {
      build = s.substring(plus + 1);
      s = s.substring(0, plus);
      if (!_identifiersRe.hasMatch(build)) return null;
    }

    // Pre-release is everything after the first '-' (the core has no '-').
    final dash = s.indexOf('-');
    String? pre;
    if (dash >= 0) {
      pre = s.substring(dash + 1);
      s = s.substring(0, dash);
      if (!_identifiersRe.hasMatch(pre)) return null;
      final preParts = pre.split('.');
      for (final id in preParts) {
        if (_numericRe.hasMatch(id) && _hasLeadingZero(id)) return null;
      }
    }

    final parts = s.split('.');
    if (parts.length != 3) return null;
    final numbers = <int>[];
    for (final part in parts) {
      if (!_numericRe.hasMatch(part) || _hasLeadingZero(part)) return null;
      final value = int.tryParse(part);
      if (value == null) return null;
      numbers.add(value);
    }

    return SemanticVersion._(
      numbers[0],
      numbers[1],
      numbers[2],
      pre == null ? const <String>[] : pre.split('.'),
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    final byMajor = major.compareTo(other.major);
    if (byMajor != 0) return byMajor;
    final byMinor = minor.compareTo(other.minor);
    if (byMinor != 0) return byMinor;
    final byPatch = patch.compareTo(other.patch);
    if (byPatch != 0) return byPatch;

    if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
    if (prerelease.isEmpty) return 1;
    if (other.prerelease.isEmpty) return -1;

    final shared = prerelease.length < other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var i = 0; i < shared; i++) {
      final result = _comparePreIdentifier(prerelease[i], other.prerelease[i]);
      if (result != 0) return result;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  static bool _hasLeadingZero(String digits) =>
      digits.length > 1 && digits.startsWith('0');

  static int _comparePreIdentifier(String a, String b) {
    final aNumeric = _numericRe.hasMatch(a);
    final bNumeric = _numericRe.hasMatch(b);
    if (aNumeric && bNumeric) {
      // Numeric identifiers have no leading zeros in practice, so length then
      // lexical order is a numeric order.
      final byLength = a.length.compareTo(b.length);
      if (byLength != 0) return byLength;
      return a.compareTo(b);
    }
    if (aNumeric != bNumeric) return aNumeric ? -1 : 1;
    return a.compareTo(b);
  }

  @override
  String toString() {
    final pre = prerelease.isEmpty ? '' : '-${prerelease.join('.')}';
    return '$major.$minor.$patch$pre';
  }
}

/// Result of an update check.
sealed class UpdateState {
  const UpdateState();

  /// No update to offer: the app is current, newer than the remote, or the
  /// check failed.
  static const UpdateState none = UpdateNone();
}

/// No update to offer. Use [UpdateState.none] instead of constructing this.
final class UpdateNone extends UpdateState {
  /// Creates the "no update" state.
  const UpdateNone();
}

/// A newer release exists and the user may keep using the current one.
final class UpdateAvailable extends UpdateState {
  /// Creates an optional-update state.
  const UpdateAvailable({
    required this.version,
    required this.url,
    this.sha256,
  });

  /// Remote version with the leading `v` removed, e.g. `1.2.3`.
  final String version;

  /// Release page (`html_url`), an https URL.
  final Uri url;

  /// Lowercase SHA-256 of the APK from the release body, or `null` when the
  /// line is missing or malformed.
  final String? sha256;

  @override
  String toString() =>
      'UpdateAvailable(version: $version, url: $url, sha256: $sha256)';
}

/// The current version is below the release's `min-supported` line, so the
/// user must update before continuing.
final class UpdateRequired extends UpdateState {
  /// Creates a mandatory-update state.
  const UpdateRequired({required this.version, required this.url, this.sha256});

  /// Remote version with the leading `v` removed, e.g. `1.2.3`.
  final String version;

  /// Release page (`html_url`), an https URL.
  final Uri url;

  /// Lowercase SHA-256 of the APK from the release body, or `null` when the
  /// line is missing or malformed.
  final String? sha256;

  @override
  String toString() =>
      'UpdateRequired(version: $version, url: $url, sha256: $sha256)';
}

/// Checks the latest GitHub release against the running app version.
///
/// Never throws. Network errors, timeouts, non-2xx responses (including 403
/// rate limits), malformed JSON, malformed tags and missing fields all yield
/// [UpdateState.none]. Response bodies are never logged.
class UpdateChecker {
  /// Creates a checker.
  ///
  /// Pass [dio] to inject a client (tests use a mock adapter). When it is
  /// omitted, an internal client is created and closed by [close].
  UpdateChecker({Dio? dio, this.timeout = const Duration(seconds: 10)})
    : _dio = dio ?? Dio(),
      _ownsDio = dio == null;

  /// Upper bound for the whole check, applied to connect, send and receive.
  final Duration timeout;

  final Dio _dio;
  final bool _ownsDio;

  /// Fetches the latest release and compares it with [currentVersion].
  ///
  /// [currentVersion] is the app version, e.g. `0.1.0`. If it is not a valid
  /// version, the result is [UpdateState.none].
  ///
  /// Rules when the remote tag is newer than [currentVersion]:
  /// - If the release body has a valid `min-supported:` version and the current
  ///   version is lower, the result is [UpdateRequired].
  /// - Otherwise the result is [UpdateAvailable].
  ///
  /// A remote tag that is not newer always gives [UpdateState.none], even if
  /// `min-supported` is higher. There is then nothing newer to install.
  ///
  /// A `min-supported:` value that is not a valid version is ignored, so the
  /// result is [UpdateAvailable].
  Future<UpdateState> checkForUpdate({required String currentVersion}) async {
    try {
      final current = SemanticVersion.tryParse(currentVersion);
      if (current == null) return UpdateState.none;

      final response = await _dio
          .get<String>(
            latestReleaseUrl,
            options: Options(
              headers: const {'Accept': 'application/vnd.github+json'},
              responseType: ResponseType.plain,
              connectTimeout: timeout,
              sendTimeout: timeout,
              receiveTimeout: timeout,
            ),
          )
          .timeout(timeout);

      final decoded = jsonDecode(response.data ?? '');
      if (decoded is! Map<String, dynamic>) return UpdateState.none;
      return _evaluate(decoded, current);
    } on Object {
      // Silent by design (NFR-9): every failure means "no update to show".
      return UpdateState.none;
    }
  }

  /// Closes the internal client. Does nothing for an injected [Dio].
  void close() {
    if (_ownsDio) _dio.close();
  }

  UpdateState _evaluate(Map<String, dynamic> release, SemanticVersion current) {
    final tag = release['tag_name'];
    final html = release['html_url'];
    if (tag is! String || html is! String) return UpdateState.none;

    final remote = SemanticVersion.tryParse(tag);
    if (remote == null) return UpdateState.none;
    if (remote.compareTo(current) <= 0) return UpdateState.none;

    final url = _releaseUrl(html);
    if (url == null) return UpdateState.none;

    final body = release['body'];
    final bodyText = body is String ? body : null;
    final version = remote.toString();
    final sha = _parseSha256(_lineValue(bodyText, 'sha256'));

    final minSupportedText = _lineValue(bodyText, 'min-supported');
    final minSupported = minSupportedText == null
        ? null
        : SemanticVersion.tryParse(minSupportedText);

    if (minSupported != null && current.compareTo(minSupported) < 0) {
      return UpdateRequired(version: version, url: url, sha256: sha);
    }
    return UpdateAvailable(version: version, url: url, sha256: sha);
  }

  /// Returns the first whitespace-separated token of the value after `key:` on
  /// the first line whose key matches. The key match ignores case and the
  /// whitespace around the key and colon. Line endings may be CRLF, LF or CR.
  static String? _lineValue(String? body, String key) {
    if (body == null) return null;
    for (final line in const LineSplitter().convert(body)) {
      final trimmed = line.trim();
      final colon = trimmed.indexOf(':');
      if (colon <= 0) continue;
      if (trimmed.substring(0, colon).trim().toLowerCase() != key) continue;
      final rest = trimmed.substring(colon + 1).trim();
      if (rest.isEmpty) return null;
      return rest.split(RegExp(r'\s+')).first;
    }
    return null;
  }

  /// Returns [raw] as a [Uri] only when it points at this project's release
  /// pages: https, host `github.com`, no userinfo, no port, and a path that
  /// starts with `/Amr905/Storize/releases/`. Otherwise returns `null`.
  ///
  /// The host is compared after Dart lowercases it, so `GITHUB.COM` is
  /// accepted (DNS names are case-insensitive). The path is case-sensitive.
  /// `Uri` hides an explicit default port (`:443`) and an empty userinfo
  /// (`@`), so the raw authority is checked for both.
  static Uri? _releaseUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https') return null;
    if (uri.host != 'github.com') return null;
    if (!uri.path.startsWith(_releasePathPrefix)) return null;
    final schemeSep = raw.indexOf('://');
    if (schemeSep < 0) return null;
    final rest = raw.substring(schemeSep + 3);
    final end = rest.indexOf(RegExp('[/?#]'));
    final authority = end < 0 ? rest : rest.substring(0, end);
    if (authority.contains('@') || authority.contains(':')) return null;
    return uri;
  }

  static String? _parseSha256(String? value) {
    if (value == null || !_sha256Re.hasMatch(value)) return null;
    return value.toLowerCase();
  }
}
