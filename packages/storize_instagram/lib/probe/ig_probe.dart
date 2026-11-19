import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_model/storize_model.dart';

/// What the probe recorded for one REST candidate. Status and top-level key
/// names only: never a body, a URL or a value.
final class ProbeEntry {
  /// Creates an entry.
  const ProbeEntry({
    required this.id,
    required this.label,
    required this.outcome,
    this.status,
    this.topLevelKeys = const [],
  });

  /// `IG-1` to `IG-5`.
  final String id;

  /// A fixed description of the call (no values).
  final String label;

  /// `ok`, `http_error`, `network`, `rate_limited`, `paused`, `busy`,
  /// `no_session` or `skipped`.
  final String outcome;

  /// The HTTP status, when a reply came.
  final int? status;

  /// The top-level key names of a JSON object reply, sorted.
  final List<String> topLevelKeys;

  /// Top-level keys each candidate must have to count as working (the
  /// TECH_SPEC candidate table; unverified).
  static const Map<String, List<String>> expectedKeys = {
    'IG-1': ['data'],
    'IG-2': ['reels'],
    'IG-3': ['user'],
    'IG-4': ['user'],
    'IG-5': ['items'],
  };

  /// Whether the call answered 200 with the key the extractor would read.
  bool get proven =>
      status == 200 &&
      (expectedKeys[id] ?? const []).every(topLevelKeys.contains);

  /// One line, for the console.
  String render() {
    final keys = topLevelKeys.join(',');
    return '$id $label outcome=$outcome status=${status ?? '-'} '
        'keys=[$keys] proven=$proven';
  }

  /// JSON form for the report.
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'outcome': outcome,
    'status': status,
    'topLevelKeys': topLevelKeys,
    'proven': proven,
  };
}

/// What the plain CDN download check recorded for one file.
final class CdnEntry {
  /// Creates an entry.
  const CdnEntry({
    required this.label,
    required this.outcome,
    this.status,
    this.contentType,
  });

  /// `story_image` or `story_video` (or another fixed label).
  final String label;

  /// `ok`, `http_error` or `network`.
  final String outcome;

  /// The HTTP status.
  final int? status;

  /// The MIME type of the reply.
  final String? contentType;

  /// One line, for the console.
  String render() =>
      'CDN $label outcome=$outcome status=${status ?? '-'} '
      'type=${contentType ?? '-'}';

  /// JSON form for the report.
  Map<String, Object?> toJson() => {
    'label': label,
    'outcome': outcome,
    'status': status,
    'contentType': contentType,
  };
}

/// The probe result: safe to paste into an issue or a doc.
final class ProbeReport {
  /// Creates a report.
  const ProbeReport({required this.entries, this.cdn = const []});

  /// One entry per candidate.
  final List<ProbeEntry> entries;

  /// The CDN checks, when they ran.
  final List<CdnEntry> cdn;

  /// Whether every REST candidate answered as expected.
  bool get restProven => entries.isNotEmpty && entries.every((e) => e.proven);

  /// A copy with [more] CDN entries added.
  ProbeReport withCdn(List<CdnEntry> more) =>
      ProbeReport(entries: entries, cdn: [...cdn, ...more]);

  /// JSON form.
  Map<String, Object?> toJson() => {
    'restProven': restProven,
    'entries': [for (final e in entries) e.toJson()],
    'cdn': [for (final c in cdn) c.toJson()],
  };

  /// One line per call, for the console or the diagnostic screen.
  String render() {
    final lines = <String>[
      for (final e in entries) e.render(),
      for (final c in cdn) c.render(),
      'restProven=$restProven',
    ];
    return lines.join('\n');
  }
}

/// Dev-only live probe (T-013 AC7, step 0): sends IG-1 to IG-5 once each
/// through the governor and records only the status and the top-level key
/// names. It is run on the dev phone (P-4) with the real session. How to run
/// it is in `docs/03-specs/INSTAGRAM_EXTRACTION.md`.
///
/// It never logs or returns bodies, cookies, URLs or query values. The
/// username and user id you pass in are used only to build the requests.
final class IgProbe {
  /// Creates the probe for the login account [accountId].
  IgProbe({
    required this.accountId,
    required this._governor,
    required this._sessions,
    required this._http,
    this._log,
    this.appId,
  });

  /// The login account.
  final int accountId;

  /// `X-IG-App-ID`, when known.
  final String? appId;

  final RequestGovernor _governor;
  final SessionStore _sessions;
  final IgHttp _http;
  final DiagnosticLog? _log;

  static const int _maxKeys = 40;
  static final RegExp _unsafeKeyChar = RegExp('[^A-Za-z0-9_]');

  /// Sends IG-1 to IG-5 once each, in order. [username] and [userId] belong
  /// to one tracked test account. After a rate limit or a pause the rest are
  /// `skipped`.
  Future<ProbeReport> run({
    required String username,
    required String userId,
  }) async {
    final session = await IgSession.load(_sessions, accountId, appId: appId);
    final calls = <(String, String, IgRequest)>[
      ('IG-1', 'users/web_profile_info', RestRequests.webProfileInfo(username)),
      ('IG-2', 'feed/reels_media', RestRequests.reelsMedia([userId])),
      ('IG-3', 'users/info', RestRequests.userInfo(userId)),
      ('IG-4', 'accounts/current_user', RestRequests.currentUser()),
      ('IG-5', 'feed/user', RestRequests.userFeed(userId)),
    ];
    final entries = <ProbeEntry>[];
    var stop = false;
    for (final (id, label, request) in calls) {
      ProbeEntry entry;
      if (session == null) {
        entry = ProbeEntry(id: id, label: label, outcome: 'no_session');
      } else if (stop) {
        entry = ProbeEntry(id: id, label: label, outcome: 'skipped');
      } else {
        entry = await _one(id, label, request.withHeaders(session.headers()));
        stop = const {'rate_limited', 'paused', 'busy'}.contains(entry.outcome);
      }
      _log?.log(
        LogLevel.info,
        'probe',
        '$id outcome=${entry.outcome} status=${entry.status ?? '-'} '
            'keys=${entry.topLevelKeys.length}',
      );
      entries.add(entry);
    }
    return ProbeReport(entries: entries);
  }

  /// The plain CDN download check (T-002 AC2): one ranged GET per file,
  /// **without** cookies or session headers, recording status and content
  /// type. CDN requests are not governed (ADR-9). Pass the media of a real
  /// story from `DirectExtractor.fetchStories`: the URLs are signed and are
  /// never recorded.
  Future<List<CdnEntry>> checkCdn(Map<String, RemoteMedia> files) async {
    final out = <CdnEntry>[];
    for (final MapEntry(key: label, value: media) in files.entries) {
      final request = IgRequest(
        method: IgMethod.get,
        uri: Uri.parse(media.url),
        headers: const {'Range': 'bytes=0-1023'},
      );
      try {
        final reply = await _http.send(request);
        out.add(
          CdnEntry(
            label: label,
            outcome: reply.status == 200 || reply.status == 206
                ? 'ok'
                : 'http_error',
            status: reply.status,
            contentType: reply.contentType,
          ),
        );
      } on TransportException {
        out.add(CdnEntry(label: label, outcome: 'network'));
      }
      _log?.log(
        LogLevel.info,
        'probe',
        'CDN $label outcome=${out.last.outcome}',
      );
    }
    return out;
  }

  Future<ProbeEntry> _one(String id, String label, IgRequest request) async {
    try {
      final result = await _governor.run<Result<IgReply>>(
        accountId: accountId,
        cost: RequestCost.api,
        call: () async {
          try {
            final reply = await _http.send(request);
            // Feed a rate limit to the governor; record every other status.
            final failure = reply.status == 429
                ? RateLimited(reply.retryAfter)
                : null;
            return failure == null ? Ok(reply) : Err(failure);
          } on TransportException {
            return const Err(NetworkFailure());
          }
        },
      );
      switch (result) {
        case Ok(:final value):
          return ProbeEntry(
            id: id,
            label: label,
            outcome: value.isSuccess ? 'ok' : 'http_error',
            status: value.status,
            topLevelKeys: _keysOf(value.json),
          );
        case Err(:final failure):
          return ProbeEntry(
            id: id,
            label: label,
            outcome: failure is RateLimited ? 'rate_limited' : 'network',
            status: failure is RateLimited ? 429 : null,
          );
      }
    } on GovernorPaused {
      return ProbeEntry(id: id, label: label, outcome: 'paused');
    } on GovernorBusy {
      return ProbeEntry(id: id, label: label, outcome: 'busy');
    }
  }

  String _safeKey(String key) {
    final safe = key.replaceAll(_unsafeKeyChar, '?');
    return safe.length > 40 ? safe.substring(0, 40) : safe;
  }

  List<String> _keysOf(Object? json) {
    if (json is! Map<String, Object?>) return const [];
    final keys = [
      for (final k in json.keys) _safeKey(k),
    ]..sort();
    return keys.take(_maxKeys).toList();
  }
}
