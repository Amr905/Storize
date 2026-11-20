/// One CDN reply: the status and the body as a stream.
///
/// The body is **not** read yet. Cancelling its subscription must close the
/// connection, so a caller that stops early (or that gets an error status)
/// does not download the rest.
final class CdnResponse {
  /// Creates a reply.
  const CdnResponse({
    required this.status,
    required this.body,
    this.contentRange,
    this.contentLength,
  });

  /// The HTTP status code.
  final int status;

  /// The body bytes.
  final Stream<List<int>> body;

  /// The `Content-Range` header of a 206 reply, when sent.
  final String? contentRange;

  /// The `Content-Length` of this reply's body, when known.
  final int? contentLength;

  @override
  String toString() => 'CdnResponse(status: $status)';
}

/// A plain HTTPS GET for CDN files (CDN-1), as a small interface so tests use
/// a fake and the app supplies the real client.
///
/// Implementations must send **no cookies and no session headers**: only the
/// headers passed in (the opener passes `Range`). They must not follow
/// redirects (a redirect could leave the CDN host allowlist) and must throw
/// `TransportException` (from `ig_http.dart`) for a socket error or timeout,
/// without the text of the original error.
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class CdnHttp {
  /// Sends a GET to [uri] with [headers].
  Future<CdnResponse> get(Uri uri, {Map<String, String> headers});
}
