import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

void main() {
  final captured = DateTime.utc(2026, 11, 19, 8);

  SessionBlob blob({
    Map<String, String>? cookies,
    String userAgent = 'Mozilla/5.0 (Linux; Android 14)',
    DateTime? capturedAt,
  }) => SessionBlob(
    cookies:
        cookies ??
        {'sessionid': 'FAKE-SESSION-VALUE', 'csrftoken': 'FAKE-CSRF-VALUE'},
    userAgent: userAgent,
    capturedAt: capturedAt ?? captured,
  );

  group('equality', () {
    test('equal blobs are equal and hash alike', () {
      expect(blob(), blob());
      expect(blob().hashCode, blob().hashCode);
    });

    test('cookie maps compare by content, regardless of insertion order', () {
      final a = blob(cookies: {'a': '1', 'b': '2'});
      final b = blob(cookies: {'b': '2', 'a': '1'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('each field affects equality', () {
      expect(blob(), isNot(blob(cookies: {'sessionid': 'other'})));
      expect(blob(), isNot(blob(userAgent: 'Other UA')));
      expect(blob(), isNot(blob(capturedAt: DateTime.utc(2026))));
    });
  });

  group('redaction', () {
    test('toString shows cookie names and never their values', () {
      final text = blob().toString();

      expect(text, contains('sessionid'));
      expect(text, contains('csrftoken'));
      expect(text, isNot(contains('FAKE-SESSION-VALUE')));
      expect(text, isNot(contains('FAKE-CSRF-VALUE')));
    });

    test('toString has the documented shape', () {
      expect(
        blob().toString(),
        'SessionBlob(cookies: [sessionid, csrftoken], '
        'userAgent: Mozilla/5.0 (Linux; Android 14), '
        'capturedAt: 2026-11-19T08:00:00.000Z)',
      );
    });

    test('an interpolated blob is redacted too', () {
      expect('${blob()}', isNot(contains('FAKE-SESSION-VALUE')));
    });
  });

  group('immutability', () {
    test('the cookie map is unmodifiable and detached from the input', () {
      final source = <String, String>{'sessionid': 'x'};
      final b = blob(cookies: source);

      source['extra'] = 'y';

      expect(b.cookies.containsKey('extra'), isFalse);
      expect(() => b.cookies['z'] = 'w', throwsUnsupportedError);
    });
  });
}
