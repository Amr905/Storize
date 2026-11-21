import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/onboarding/login_host_policy.dart';

void main() {
  bool ok(String u) => LoginHostPolicy.allows(Uri.parse(u));

  test('allows the instagram and facebook login hosts', () {
    expect(ok('https://www.instagram.com/accounts/login/'), isTrue);
    expect(ok('https://instagram.com/'), isTrue);
    expect(ok('https://m.facebook.com/login.php'), isTrue);
    expect(ok('https://web.facebook.com/v2/dialog'), isTrue);
  });

  test('blocks other hosts, look-alikes, redirectors and non-https', () {
    expect(ok('https://evil.com/'), isFalse);
    expect(ok('https://instagram.com.evil.com/'), isFalse);
    expect(ok('https://notinstagram.com/'), isFalse);
    expect(ok('https://evilfacebook.com/'), isFalse);
    expect(ok('https://l.instagram.com/?u=https%3A%2F%2Fevil.com'), isFalse);
    expect(ok('http://www.instagram.com/'), isFalse);
    expect(ok('intent://scan'), isFalse);
    expect(ok('about:blank'), isFalse);
    expect(ok('file:///etc/passwd'), isFalse);
  });
}
