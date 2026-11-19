import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/debug/hook_message.dart';

Map<String, Object?> _good() => {
  'url': 'https://www.instagram.com/api/v1/feed/reels_media/?reel_ids=1',
  'status': 200,
  'bodyLength': 1234,
  'topLevelKeys': ['reels', 'status'],
  'origin': 'https://www.instagram.com',
  'via': 'fetch',
};

void main() {
  const ok = 'https://www.instagram.com';

  test('accepts a good message from the instagram origin', () {
    final r = parseHookMessage([_good()], pageOrigin: ok);
    expect(r, isNotNull);
    expect(r!.status, 200);
    expect(r.bodyLength, 1234);
    expect(r.topLevelKeys, ['reels', 'status']);
    expect(r.via, 'fetch');
    expect(r.shortUrl, 'www.instagram.com/api/v1/feed/reels_media/');
  });

  test('accepts a bare map and a JSON string', () {
    expect(parseHookMessage(_good(), pageOrigin: ok), isNotNull);
    expect(
      parseHookMessage(
        '{"url":"https://i.instagram.com/api/v1/x/","status":404,'
        '"bodyLength":0,"topLevelKeys":[],"origin":"$ok"}',
        pageOrigin: ok,
      ),
      isNotNull,
    );
  });

  test('rejects a page origin that is not https://www.instagram.com', () {
    for (final o in [
      '',
      'https://evil.example.com',
      'http://www.instagram.com',
      'https://instagram.com',
      'https://www.instagram.com.evil.com',
      'https://m.instagram.com',
    ]) {
      expect(parseHookMessage(_good(), pageOrigin: o), isNull, reason: o);
    }
  });

  test('rejects a payload that claims a different origin', () {
    final m = _good()..['origin'] = 'https://evil.example.com';
    expect(parseHookMessage(m, pageOrigin: ok), isNull);
    final missing = _good()..remove('origin');
    expect(parseHookMessage(missing, pageOrigin: ok), isNull);
  });

  test('rejects a request URL that is not on instagram.com', () {
    for (final u in [
      'https://evil.example.com/api',
      'https://instagram.com.evil.com/api',
      'http://www.instagram.com/api',
      'not a url',
    ]) {
      final m = _good()..['url'] = u;
      expect(parseHookMessage(m, pageOrigin: ok), isNull, reason: u);
    }
  });

  test('rejects malformed shapes', () {
    expect(parseHookMessage(null, pageOrigin: ok), isNull);
    expect(parseHookMessage('nope', pageOrigin: ok), isNull);
    expect(parseHookMessage(<Object?>[], pageOrigin: ok), isNull);
    expect(parseHookMessage(42, pageOrigin: ok), isNull);
    expect(
      parseHookMessage(_good()..['status'] = '200', pageOrigin: ok),
      isNull,
    );
    expect(
      parseHookMessage(_good()..['bodyLength'] = -1, pageOrigin: ok),
      isNull,
    );
    expect(
      parseHookMessage(_good()..['topLevelKeys'] = [1], pageOrigin: ok),
      isNull,
    );
    expect(
      parseHookMessage(_good()..['topLevelKeys'] = 'x', pageOrigin: ok),
      isNull,
    );
  });

  test('caps the number of keys', () {
    final m = _good()..['topLevelKeys'] = [for (var i = 0; i < 80; i++) 'k$i'];
    expect(parseHookMessage(m, pageOrigin: ok)!.topLevelKeys, hasLength(50));
  });
}
