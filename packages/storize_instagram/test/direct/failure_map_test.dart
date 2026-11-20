// AC4: every row of the TECH_SPEC 4.1 failure map has a fixture test. The
// bodies are synthetic and unverified (test/fixtures/synthetic/failures).
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

typedef _Row = (String name, IgReply reply, Failure expected);

Object? _f(String name) => loadSynthetic('failures/$name.json');

final List<_Row> _rows = [
  (
    '401',
    jsonReply(_f('login_required'), status: 401),
    const SessionInvalid(SessionReason.loginRequired),
  ),
  (
    '400 login_required',
    jsonReply(_f('login_required'), status: 400),
    const SessionInvalid(SessionReason.loginRequired),
  ),
  (
    '401 without a body',
    const IgReply(status: 401),
    const SessionInvalid(SessionReason.loginRequired),
  ),
  (
    'redirect to login',
    const IgReply(status: 302, redirectPath: '/accounts/login/'),
    const SessionInvalid(SessionReason.loginRequired),
  ),
  (
    '200 GraphQL login_required with data null',
    jsonReply(_f('graphql_login_required')),
    const SessionInvalid(SessionReason.loginRequired),
  ),
  (
    '200 status fail login_required',
    jsonReply(_f('login_required')),
    const SessionInvalid(SessionReason.loginRequired),
  ),
  (
    'checkpoint_required',
    jsonReply(_f('checkpoint_required'), status: 400),
    const SessionInvalid(SessionReason.challenge),
  ),
  (
    'challenge_required',
    jsonReply(_f('challenge_required'), status: 403),
    const SessionInvalid(SessionReason.challenge),
  ),
  (
    'feedback_required',
    jsonReply(_f('feedback_required'), status: 400),
    const AccountRestricted(),
  ),
  (
    'account disabled',
    jsonReply(_f('account_disabled'), status: 403),
    const AccountRestricted(),
  ),
  (
    '429 with Retry-After',
    jsonReply(
      _f('please_wait'),
      status: 429,
      retryAfter: const Duration(seconds: 90),
    ),
    const RateLimited(Duration(seconds: 90)),
  ),
  ('429 without a hint', const IgReply(status: 429), const RateLimited(null)),
  (
    '"Please wait" on a 400',
    jsonReply(_f('please_wait'), status: 400),
    const RateLimited(null),
  ),
  ('404', jsonReply(_f('not_found'), status: 404), const TargetNotFound()),
  (
    'private and not followed',
    jsonReply(_f('not_authorized'), status: 403),
    const TargetNotVisible(),
  ),
  ('500', const IgReply(status: 500), const UnknownFailure(500, 'http_500')),
  (
    '403 without a marker',
    const IgReply(status: 403),
    const UnknownFailure(403, 'http_403'),
  ),
  (
    '200 that is not JSON (an HTML page)',
    const IgReply(status: 200, contentType: 'text/html'),
    const SchemaChanged('response'),
  ),
  (
    '200 status fail with no known marker',
    jsonReply({'status': 'fail', 'message': 'ZZFAKE'}),
    const UnknownFailure(null, 'status_fail'),
  ),
];

void main() {
  const classifier = FailureClassifier();

  group('AC4 classifier, one test per row of the failure map', () {
    for (final (name, reply, expected) in _rows) {
      test(name, () => expect(classifier.classify(reply), expected));
    }

    test('a good JSON object is not a failure', () {
      expect(
        classifier.classify(jsonReply({'data': <String, Object?>{}})),
        isNull,
      );
    });

    test('AC8 non-fatal errors[] next to complete data is not a failure, '
        'even when a message looks like a marker', () {
      final body = {
        'data': {'user': <String, Object?>{}},
        'errors': [
          {'message': 'login_required in a sub-field', 'severity': 'ERROR'},
        ],
      };
      expect(classifier.classify(jsonReply(body)), isNull);
      expect(
        classifier.classify(jsonReply(loadSynthetic('timeline.json'))),
        isNull,
      );
    });
  });

  group('AC4 end to end through the extractor (governed, GraphQL)', () {
    for (final (name, reply, expected) in _rows) {
      test(name, () async {
        final rig = Rig(responder: (_) => reply);
        final result = await rig.run(
          rig.extractor.fetchStories(['ZZFAKE_user_a']),
        );
        expect(result.failureOrNull, expected);
        expect(rig.http.requests, hasLength(1));
      });
    }

    test('user null in a 200 answer is TargetNotFound', () async {
      final rig = Rig(
        responder: graphqlResponder(
          profile: loadSynthetic('failures/graphql_user_null.json'),
        ),
      );
      final result = await rig.run(rig.extractor.refreshUser('ZZFAKE_u', ''));
      expect(result.failureOrNull, const TargetNotFound());
    });

    test('socket error or timeout is NetworkFailure', () async {
      for (final kind in ['socket', 'timeout']) {
        final rig = Rig(responder: (_) => throw TransportException(kind));
        final result = await rig.run(
          rig.extractor.fetchStories(['ZZFAKE_user_a']),
        );
        expect(result.failureOrNull, const NetworkFailure(), reason: kind);
      }
    });

    test('missing fields are SchemaChanged with the path', () async {
      final rig = Rig(
        responder: (_) => jsonReply({'data': <String, Object?>{}}),
      );
      final result = await rig.run(
        rig.extractor.fetchStories(['ZZFAKE_user_a']),
      );
      expect(
        result.failureOrNull,
        const SchemaChanged(
          'response.data.xdt_api__v1__feed__reels_media.reels_media',
        ),
      );
    });
  });
}
