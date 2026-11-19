import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:storize_instagram/direct/ig_http.dart';

/// An [IgHttp] on `dart:io`, with no extra dependency.
///
/// It never follows redirects, never stores cookies of its own, and throws
/// [TransportException] on a socket error or a timeout. Bodies are read up to
/// [maxBodyBytes]; a body that starts with `{` or `[` is decoded as JSON,
/// anything else leaves `json` null.
final class DartIoHttp implements IgHttp {
  /// Creates the client.
  DartIoHttp({
    this.timeout = const Duration(seconds: 30),
    this.maxBodyBytes = 8 * 1024 * 1024,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  /// Per-request timeout.
  final Duration timeout;

  /// Read at most this many body bytes.
  final int maxBodyBytes;

  final HttpClient _client;

  @override
  Future<IgReply> send(IgRequest request) async {
    try {
      return await _send(request).timeout(timeout);
    } on TimeoutException {
      throw const TransportException('timeout');
    } on SocketException {
      throw const TransportException('socket');
    } on HttpException {
      throw const TransportException('socket');
    } on HandshakeException {
      throw const TransportException('socket');
    }
  }

  Future<IgReply> _send(IgRequest request) async {
    final call = request.method == IgMethod.get
        ? await _client.getUrl(request.uri)
        : await _client.postUrl(request.uri);
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
    await for (final chunk in response) {
      if (bytes.length < maxBodyBytes) bytes.add(chunk);
    }
    final contentType = response.headers.contentType?.mimeType;
    Object? json;
    final body = bytes.takeBytes();
    final first = body.isEmpty ? 0 : body.first;
    // `{` or `[`: JSON whatever the content type says (GraphQL answers can
    // come as text/javascript).
    if (first == 0x7B || first == 0x5B) {
      try {
        json = jsonDecode(utf8.decode(body));
      } on FormatException {
        json = null;
      }
    }
    final retry = int.tryParse(response.headers.value('retry-after') ?? '');
    final location = response.headers.value('location');
    return IgReply(
      status: response.statusCode,
      json: json,
      retryAfter: retry == null || retry < 0 ? null : Duration(seconds: retry),
      redirectPath: location == null ? null : Uri.tryParse(location)?.path,
      contentType: contentType,
    );
  }
}
