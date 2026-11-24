/// HTTP verbs the direct extractor uses.
enum IgMethod {
  /// A GET request.
  get,

  /// A form-encoded POST request.
  post,
}

/// One HTTP request, before the session headers are added.
///
/// `toString` shows only the method, the host and the path with ids replaced
/// by `<id>`: ids, query values and form fields can hold tokens and signed
/// URLs, so they never reach a log.
final class IgRequest {
  /// Creates a request.
  const IgRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.form,
  });

  /// A GET to `https://<host><path>` with an optional query.
  ///
  /// Repeated names are allowed (`reel_ids` is sent once per id).
  factory IgRequest.get({
    required String path,
    String host = 'www.instagram.com',
    List<(String, String)> query = const [],
  }) {
    final params = <String, List<String>>{};
    for (final (name, value) in query) {
      (params[name] ??= []).add(value);
    }
    return IgRequest(
      method: IgMethod.get,
      uri: Uri.https(host, path, params.isEmpty ? null : params),
    );
  }

  /// A form-encoded POST to `https://<host><path>`.
  factory IgRequest.postForm({
    required String path,
    required Map<String, String> form,
    String host = 'www.instagram.com',
  }) =>
      IgRequest(method: IgMethod.post, uri: Uri.https(host, path), form: form);

  /// The verb.
  final IgMethod method;

  /// The full URL.
  final Uri uri;

  /// Extra headers. The session headers are added by the extractor.
  final Map<String, String> headers;

  /// The form fields of a POST.
  final Map<String, String>? form;

  /// A copy with [extra] headers merged over the current ones.
  IgRequest withHeaders(Map<String, String> extra) => IgRequest(
    method: method,
    uri: uri,
    headers: {...headers, ...extra},
    form: form,
  );

  /// Path segments that are fixed words of the API. Every other segment can
  /// be an id and is printed as `<id>`.
  static const Set<String> _knownSegments = {
    'api',
    'v1',
    'users',
    'user',
    'info',
    'feed',
    'reels_media',
    'accounts',
    'current_user',
    'web_profile_info',
    'graphql',
    'media',
  };

  @override
  String toString() {
    final path = [
      for (final s in uri.pathSegments)
        if (s.isEmpty || _knownSegments.contains(s)) s else '<id>',
    ].join('/');
    return 'IgRequest(${method.name} ${uri.host}/$path)';
  }
}

/// One HTTP response. The body is already decoded when it was JSON.
final class IgReply {
  /// Creates a reply.
  const IgReply({
    required this.status,
    this.json,
    this.retryAfter,
    this.redirectPath,
    this.contentType,
  });

  /// The HTTP status code.
  final int status;

  /// The decoded JSON body, or null when the body was not JSON.
  final Object? json;

  /// The `Retry-After` hint, when sent.
  final Duration? retryAfter;

  /// The path (no query) of a `Location` header on a redirect.
  final String? redirectPath;

  /// The response `Content-Type`, when sent.
  final String? contentType;

  /// Whether the status is 2xx.
  bool get isSuccess => status >= 200 && status < 300;

  @override
  String toString() => 'IgReply(status: $status)';
}

/// The request could not be completed: socket error, DNS failure or timeout.
final class TransportException implements Exception {
  /// Creates the exception. [kind] is `timeout` or `socket`.
  const TransportException(this.kind);

  /// `timeout` or `socket`.
  final String kind;

  @override
  String toString() => 'TransportException($kind)';
}

/// Sends HTTP requests. The platform wiring (T-015) supplies the real one;
/// tests use a fake. It must not follow redirects, so a redirect to the login
/// page stays visible, and it throws [TransportException] for network errors.
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class IgHttp {
  /// Sends [request] and returns the reply.
  Future<IgReply> send(IgRequest request);
}
