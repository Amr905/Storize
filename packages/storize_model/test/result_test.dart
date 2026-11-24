import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

/// Switches over [Result] with no default case. If [Result] stops being
/// exhaustively switchable, this file fails to analyze.
String describeResult<T>(Result<T> result) => switch (result) {
  Ok<T>(:final value) => 'ok:$value',
  Err<T>(:final failure) => 'err:${failure.runtimeType}',
};

void main() {
  group('Ok equality', () {
    test('equal values are equal and hash alike', () {
      expect(const Ok(1), const Ok(1));
      expect(const Ok(1).hashCode, const Ok(1).hashCode);
    });

    test('different values are not equal', () {
      expect(const Ok(1), isNot(const Ok(2)));
    });

    test('nested list values compare by content', () {
      expect(const Ok<List<int>>([1, 2]), const Ok<List<int>>([1, 2]));
      expect(
        const Ok<List<int>>([1, 2]).hashCode,
        const Ok<List<int>>([1, 2]).hashCode,
      );
      expect(const Ok<List<int>>([1, 2]), isNot(const Ok<List<int>>([2, 1])));
    });

    test('Ok is not equal to Err', () {
      expect(const Ok<int>(1), isNot(const Err<int>(NetworkFailure())));
    });
  });

  group('Err equality', () {
    test('equal failures are equal and hash alike', () {
      expect(
        const Err<int>(RateLimited(Duration(minutes: 5))),
        const Err<int>(RateLimited(Duration(minutes: 5))),
      );
      expect(
        const Err<int>(RateLimited(Duration(minutes: 5))).hashCode,
        const Err<int>(RateLimited(Duration(minutes: 5))).hashCode,
      );
    });

    test('different failures are not equal', () {
      expect(
        const Err<int>(NetworkFailure()),
        isNot(const Err<int>(TargetNotFound())),
      );
    });
  });

  group('convenience members', () {
    test('isOk, isErr, valueOrNull and failureOrNull', () {
      const ok = Ok<int>(7);
      const err = Err<int>(NetworkFailure());

      expect(ok.isOk, isTrue);
      expect(ok.isErr, isFalse);
      expect(ok.valueOrNull, 7);
      expect(ok.failureOrNull, isNull);

      expect(err.isOk, isFalse);
      expect(err.isErr, isTrue);
      expect(err.valueOrNull, isNull);
      expect(err.failureOrNull, const NetworkFailure());
    });

    test('map transforms Ok and passes Err through', () {
      expect(const Ok<int>(2).map((v) => v * 10), const Ok<int>(20));
      expect(
        const Err<int>(TargetNotVisible()).map((v) => v * 10),
        const Err<int>(TargetNotVisible()),
      );
    });

    test('when calls the matching branch', () {
      String fold(Result<int> r) =>
          r.when(ok: (v) => 'value $v', err: (f) => 'failure ${f.runtimeType}');

      expect(fold(const Ok(3)), 'value 3');
      expect(fold(const Err(AccountRestricted())), 'failure AccountRestricted');
    });
  });

  group('exhaustive switch', () {
    test('switches over Result without a default case', () {
      expect(describeResult(const Ok<int>(4)), 'ok:4');
      expect(
        describeResult(const Err<int>(SchemaChanged('x'))),
        'err:SchemaChanged',
      );
    });
  });
}
