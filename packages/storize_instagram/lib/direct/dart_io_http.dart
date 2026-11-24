import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:storize_instagram/direct/failure_classifier.dart';
import 'package:storize_instagram/direct/ig_http.dart';

/// An [IgHttp] on `dart:io`, with no extra dependency.
///
/// It never follows redirects, never stores cookies of its own, and throws
/// [TransportException] on a socket error or a timeout. Bodies are read up to
/// [maxBodyBytes] (past it the connection is aborted and `json` is null); a
/// body that starts with `{` or `[` is decoded as JSON, anything else leaves
/// `json` null. A timeout aborts the request. Any other error becomes a
/// [TransportException] **without** the original text, which can contain a
/// header value such as a cookie.
final class DartIoHttp implements IgHttp {
  /// Creates the client.
  DartIoHttp({
    this.timeout = const Duration(seconds: 30),
    this.maxBodyBytes = 8 * 1024 * 1024,
    HttpClient? client,
  }) : _client = client ?? (HttpClient()..connectionTimeout = timeout);

  /// Per-request timeout.
  final Duration timeout;

  /// Read at most this many body bytes.
  final int maxBodyBytes;

  final HttpClient _client;

  @override
  Future<IgReply> send(IgRequest request) async {
    final pending = _Pending();
    try {
      return await _send(request, pending).timeout(timeout);
    } on TimeoutException {
      pending.abort();
      throw const TransportException('timeout');
    } on Object {
      // Whatever it was (socket, TLS, a header the platform refuses), its
      // text may carry a request value such as a cookie: never pass it on.
      pending.abort();
      throw const TransportException('socket');
    }
  }

  Future<IgReply> _send(IgRequest request, _Pending pending) async {
    final call = request.method == IgMethod.get
        ? await _client.getUrl(request.uri)
        : await _client.postUrl(request.uri);
    pending.call = call;
    final headers = call.headers;
    request.headers.forEach(headers.set);
    call.followRedirects = false;
    final form = request.form;
    if (form != null) {
      headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      call.write(
        form.entries
            .map(
              (e) =>
                  '${Uri.encodeQueryComponent(e.key)}='
                  '${Uri.encodeQueryComponent(e.value)}',
            )
            .join('&'),
      );
    }
    final response = await call.close();
    final bytes = BytesBuilder(copy: false);
    var tooLarge = false;
    final done = Completer<void>();
    // Cancelling the subscription closes the connection, so a timeout or the
    // size cap stops the transfer instead of draining it.
    pending.sub = response.listen(
      (chunk) {
        bytes.add(chunk);
        if (bytes.length > maxBodyBytes && !done.isCompleted) {
          tooLarge = true;
          pending.abort();
          done.complete();
        }
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (Object e, StackTrace s) {
        if (!done.isCompleted) done.completeError(e, s);
      },
      cancelOnError: true,
    );
    await done.future;
    final contentType = response.headers.contentType?.mimeType;
    Object? json;
    final body = tooLarge ? Uint8List(0) : bytes.takeBytes();
    final first = body.isEmpty ? 0 : body.first;
    // `{` or `[`: JSON whatever the content type says (GraphQL answers can
    // come as text/javascript).
    var shielded = false;
    if (first == 0x7B || first == 0x5B) {
      try {
        json = jsonDecode(utf8.decode(body));
      } on FormatException {
        json = null;
      }
    } else if (first == 0x66 && body.length > _guard.length) {
      // `for (;;);{...}`: the JSON error body of the web app (T-049).
      final text = utf8.decode(body, allowMalformed: true);
      if (text.startsWith('for (;;);')) {
        try {
          json = jsonDecode(text.substring(_guard.length));
          shielded = json is Map<String, Object?>;
          if (!shielded) json = null;
        } on FormatException {
          json = null;
        }
      }
    }
    final retryAfter = _parseRetryAfter(response.headers.value('retry-after'));
    final location = response.headers.value('location');
    return IgReply(
      status: response.statusCode,
      json: json,
      retryAfter: retryAfter,
      redirectPath: location == null ? null : Uri.tryParse(location)?.path,
      contentType: contentType,
      shielded: shielded,
    );
  }

  static const String _guard = 'for (;;);';

  /// `Retry-After` as whole seconds or as an HTTP-date. Null when missing,
  /// unreadable, negative or already past. Whole seconds are clamped before
  /// the conversion (T-013 N4), so a huge value cannot wrap.
  static Duration? _parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return clampedRetryAfter(seconds);
    try {
      final wait = HttpDate.parse(value.trim()).difference(DateTime.now());
      if (wait <= Duration.zero) return null;
      return wait > defaultMaxRetryAfter ? defaultMaxRetryAfter : wait;
    } on Object {
      return null;
    }
  }
}

/// What a running request holds, so a timeout or the size cap can close it.
final class _Pending {
  HttpClientRequest? call;
  StreamSubscription<List<int>>? sub;

  void abort() {
    call?.abort();
    unawaited(sub?.cancel());
  }
}
