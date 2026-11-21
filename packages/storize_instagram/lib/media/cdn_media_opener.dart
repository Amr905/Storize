import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/media/cdn_http.dart';
import 'package:storize_instagram/media/cdn_policy.dart';

/// `ContentPlatform.openMedia` for the Instagram CDN (CDN-1, ADR-5, ADR-9).
///
/// - **Plain GET, no cookies.** The only header sent is `Range`
///   (`bytes=<fromByte>-`, only when resuming). Session headers never reach
///   this class.
/// - **Not governed.** CDN files are not Instagram API calls and do not use
///   the request budget (ADR-9); nothing here touches the governor.
/// - **Host allowlist.** Only the URLs that `allowedCdnUri` accepts are
///   requested; anything else is a `MediaStreamFailure('url_rejected')` and
///   nothing is sent.
/// - **Resume.** `206` with a `Content-Range` that starts at `fromByte` is
///   streamed as is. A `200` (the server ignored `Range`) has its first
///   `fromByte` bytes skipped. A `Content-Range` that starts elsewhere is a
///   `range_mismatch` failure, never wrong bytes.
/// - **Errors are stream errors** (the port contract): HTTP 403 or 410 is
///   `ExpiredMediaUrl` (the caller refreshes the URL once, FR-25); everything
///   else is `MediaStreamFailure` with a status code and/or a short reason
///   (`timeout`, `socket`, `truncated`, ...). Bytes already emitted are valid.
/// - **No URLs in logs.** Only the outcome, the status code and a reason.
///
/// The stream is single-subscription. Pausing pauses the download; cancelling
/// closes the connection.
final class CdnMediaOpener {
  /// Creates the opener over [_http].
  CdnMediaOpener({
    required this._http,
    this._log,
    this.responseTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 30),
  });

  /// How long the request may take until the headers arrive.
  final Duration responseTimeout;

  /// The longest silence between two body chunks.
  final Duration idleTimeout;

  final CdnHttp _http;
  final DiagnosticLog? _log;

  /// Streams the bytes of [url] from [fromByte].
  Stream<List<int>> open(String url, {int fromByte = 0}) {
    final session = _OpenSession(this, url, fromByte);
    return session.stream;
  }

  void _logOutcome(LogLevel level, String outcome, {int? status}) {
    _log?.log(
      level,
      'media',
      'op=openMedia outcome=$outcome${status == null ? '' : ' status=$status'}',
    );
  }
}

/// A parsed `Content-Range: bytes <start>-<end>/<total>` (total may be `*`).
final class _ContentRange {
  const _ContentRange(this.start, this.total);

  final int start;
  final int? total;
}

/// `Content-Range: bytes 100-199/500` gives start 100, total 500; anything
/// else is null.
_ContentRange? _parseContentRange(String? header) {
  if (header == null) return null;
  final match = RegExp(r'^\s*bytes\s+(\d+)-\d+/(\d+|\*)\s*$')
      .firstMatch(header);
  if (match == null) return null;
  final start = int.tryParse(match.group(1)!);
  if (start == null) return null;
  return _ContentRange(start, int.tryParse(match.group(2)!));
}

final class _OpenSession {
  _OpenSession(this._owner, this._url, this._fromByte) {
    _controller = StreamController<List<int>>(
      onListen: _start,
      onPause: () => _sub?.pause(),
      onResume: () => _sub?.resume(),
      onCancel: _cancel,
    );
  }

  final CdnMediaOpener _owner;
  final String _url;
  final int _fromByte;
  late final StreamController<List<int>> _controller;
  StreamSubscription<List<int>>? _sub;
  bool _cancelled = false;
  bool _finished = false;
  int _toSkip = 0;
  int _received = 0;
  int? _expected;

  Stream<List<int>> get stream => _controller.stream;

  Future<void> _cancel() async {
    _cancelled = true;
    final sub = _sub;
    _sub = null;
    if (sub != null) await sub.cancel();
  }

  void _fail(MediaStreamException error, String outcome, {int? status}) {
    if (_finished || _cancelled) return;
    _finished = true;
    _owner._logOutcome(LogLevel.warn, outcome, status: status);
    _controller
      ..addError(error)
      ..close().ignore();
  }

  void _failure(String reason, {int? status}) => _fail(
    MediaStreamFailure(statusCode: status, message: reason),
    reason,
    status: status,
  );

  Future<void> _start() async {
    if (_fromByte < 0) return _failure('bad_range');
    final uri = allowedCdnUri(_url);
    if (uri == null) return _failure('url_rejected');
    final CdnResponse response;
    try {
      response = await _owner._http
          .get(uri, headers: {if (_fromByte > 0) 'Range': 'bytes=$_fromByte-'})
          .timeout(_owner.responseTimeout);
    } on TimeoutException {
      return _failure('timeout');
    } on TransportException catch (e) {
      return _failure(e.kind == 'timeout' ? 'timeout' : 'socket');
    } on Object {
      // The text of an error can carry the URL: only a fixed reason is kept.
      return _failure('socket');
    }
    if (_cancelled) {
      unawaited(response.body.listen((_) {}).cancel());
      return;
    }
    final status = response.status;
    if (status == 403 || status == 410) {
      unawaited(response.body.listen((_) {}).cancel());
      return _fail(const ExpiredMediaUrl(), 'expired', status: status);
    }
    if (status == 206) {
      // The start must match the request: `fromByte` with a Range header, 0
      // without one (T-015a F3). A missing or broken header is a mismatch.
      final range = _parseContentRange(response.contentRange);
      if (range == null || range.start != _fromByte) {
        unawaited(response.body.listen((_) {}).cancel());
        return _failure('range_mismatch', status: status);
      }
      // Without a Content-Length the total of the range says how many bytes
      // must arrive, so a short body is `truncated` (F4).
      final total = range.total;
      if (response.contentLength == null && total != null) {
        _expected = total - range.start;
      }
    } else if (status == 200) {
      _toSkip = _fromByte;
    } else {
      unawaited(response.body.listen((_) {}).cancel());
      return _failure(
        status == 416 ? 'range_not_satisfiable' : 'http_error',
        status: status,
      );
    }
    _expected ??= response.contentLength;
    _sub = response.body
        .timeout(_owner.idleTimeout)
        .listen(
          _onData,
          onError: (Object error) =>
              _failure(error is TimeoutException ? 'timeout' : 'socket'),
          onDone: _onDone,
          cancelOnError: true,
        );
    if (_controller.isPaused) _sub?.pause();
  }

  void _onData(List<int> chunk) {
    _received += chunk.length;
    var out = chunk;
    if (_toSkip > 0) {
      if (chunk.length <= _toSkip) {
        _toSkip -= chunk.length;
        return;
      }
      out = chunk.sublist(_toSkip);
      _toSkip = 0;
    }
    if (out.isNotEmpty) _controller.add(out);
  }

  void _onDone() {
    if (_finished || _cancelled) return;
    final expected = _expected;
    if (_toSkip > 0) return _failure('range_beyond_end');
    if (expected != null && _received < expected) return _failure('truncated');
    _finished = true;
    _owner._logOutcome(LogLevel.info, 'ok');
    _controller.close().ignore();
  }
}
