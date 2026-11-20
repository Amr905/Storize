import 'dart:async';
import 'dart:io';

import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/media/cdn_http.dart';

/// A [CdnHttp] on `dart:io`.
///
/// Sends only the headers it is given: no cookies (it keeps none), no
/// session. It does not follow redirects. Socket, TLS and timeout errors
/// become a `TransportException` without the original text. Cancelling the
/// body subscription closes the connection.
final class DartIoCdnHttp implements CdnHttp {
  /// Creates the client. [client] is injectable for tests.
  DartIoCdnHttp({
    this.connectTimeout = const Duration(seconds: 30),
    HttpClient? client,
  }) : _client = client ?? (HttpClient()..connectionTimeout = connectTimeout);

  /// How long connecting and waiting for the headers may take.
  final Duration connectTimeout;

  final HttpClient _client;

  @override
  Future<CdnResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    try {
      final request = await _client.getUrl(uri).timeout(connectTimeout);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(connectTimeout);
      final length = response.contentLength;
      return CdnResponse(
        status: response.statusCode,
        body: response.handleError(
          (Object _) => throw const TransportException('socket'),
        ),
        contentRange: response.headers.value(HttpHeaders.contentRangeHeader),
        contentLength: length < 0 ? null : length,
      );
    } on TimeoutException {
      throw const TransportException('timeout');
    } on Object {
      throw const TransportException('socket');
    }
  }
}
