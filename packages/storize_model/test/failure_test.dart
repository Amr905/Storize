import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

/// Switches over [Failure] with no default case. Adding a subclass without
/// adding a branch here makes this file fail to analyze.
String failureLabel(Failure failure) => switch (failure) {
  NetworkFailure() => 'network',
  RateLimited() => 'rateLimited',
  SessionInvalid() => 'sessionInvalid',
  AccountRestricted() => 'accountRestricted',
  TargetNotFound() => 'targetNotFound',
  TargetNotVisible() => 'targetNotVisible',
  SchemaChanged() => 'schemaChanged',
  UnknownFailure() => 'unknown',
};

void main() {
  group('equality', () {
    test('field-less failures are equal to the same type only', () {
      expect(const NetworkFailure(), const NetworkFailure());
      expect(const AccountRestricted(), const AccountRestricted());
      expect(const TargetNotFound(), const TargetNotFound());
      expect(const TargetNotVisible(), const TargetNotVisible());

      expect(const NetworkFailure(), isNot(const TargetNotFound()));
      expect(const NetworkFailure().hashCode, const NetworkFailure().hashCode);
    });

    test('RateLimited compares retryAfter', () {
      expect(
        const RateLimited(Duration(seconds: 30)),
        const RateLimited(Duration(seconds: 30)),
      );
      expect(
        const RateLimited(Duration(seconds: 30)).hashCode,
        const RateLimited(Duration(seconds: 30)).hashCode,
      );
      expect(
        const RateLimited(Duration(seconds: 30)),
        isNot(const RateLimited(Duration(seconds: 31))),
      );
      expect(const RateLimited(null), isNot(const RateLimited(Duration.zero)));
    });

    test('SessionInvalid compares reason', () {
      expect(
        const SessionInvalid(SessionReason.challenge),
        const SessionInvalid(SessionReason.challenge),
      );
      expect(
        const SessionInvalid(SessionReason.challenge).hashCode,
        const SessionInvalid(SessionReason.challenge).hashCode,
      );
      expect(
        const SessionInvalid(SessionReason.challenge),
        isNot(const SessionInvalid(SessionReason.loginRequired)),
      );
    });

    test('SchemaChanged compares where', () {
      expect(
        const SchemaChanged('items[0].pk'),
        const SchemaChanged('items[0].pk'),
      );
      expect(
        const SchemaChanged('items[0].pk').hashCode,
        const SchemaChanged('items[0].pk').hashCode,
      );
      expect(
        const SchemaChanged('items[0].pk'),
        isNot(const SchemaChanged('user')),
      );
    });

    test('UnknownFailure compares code and message', () {
      expect(
        const UnknownFailure(500, 'boom'),
        const UnknownFailure(500, 'boom'),
      );
      expect(
        const UnknownFailure(500, 'boom').hashCode,
        const UnknownFailure(500, 'boom').hashCode,
      );
      expect(
        const UnknownFailure(500, 'boom'),
        isNot(const UnknownFailure(503, 'boom')),
      );
      expect(
        const UnknownFailure(null, null),
        isNot(const UnknownFailure(null, 'x')),
      );
    });
  });

  group('exhaustive switch', () {
    test('every subclass maps to its own branch', () {
      expect(failureLabel(const NetworkFailure()), 'network');
      expect(failureLabel(const RateLimited(null)), 'rateLimited');
      expect(
        failureLabel(const SessionInvalid(SessionReason.loginRequired)),
        'sessionInvalid',
      );
      expect(failureLabel(const AccountRestricted()), 'accountRestricted');
      expect(failureLabel(const TargetNotFound()), 'targetNotFound');
      expect(failureLabel(const TargetNotVisible()), 'targetNotVisible');
      expect(failureLabel(const SchemaChanged('x')), 'schemaChanged');
      expect(failureLabel(const UnknownFailure(null, null)), 'unknown');
    });
  });
}
