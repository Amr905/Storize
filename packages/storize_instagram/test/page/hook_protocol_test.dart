import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/page/page.dart';

import 'support.dart';

Map<String, Object?> payload({Map<String, Object?> override = const {}}) => {
  'url': 'https://www.instagram.com/api/graphql?x=ZZFAKE',
  'status': 200,
  'origin': okOrigin,
  'friendlyName': 'SomeQuery',
  'body': '{"data":{}}',
  ...override,
};

void main() {
  group('originOf', () {
    test('drops default ports, keeps others', () {
      expect(originOf('https', 'www.instagram.com', 443), okOrigin);
      expect(originOf('https', 'www.instagram.com', 0), okOrigin);
      expect(originOf('https', 'www.instagram.com'), okOrigin);
      expect(
        originOf('https', 'www.instagram.com', 8443),
        'https://www.instagram.com:8443',
      );
      expect(allowedPageOrigins.contains(originOf('http', 'x', 80)), isFalse);
    });
  });

  group('parseHookMessage', () {
    test('a good response: path without query, json decoded', () {
      final m = parseHookMessage([payload()], pageOrigin: okOrigin);
      expect(m, isA<HookCapture>());
      final c = m as HookCapture;
      expect(c.path, '/api/graphql');
      expect(c.json, {'data': <String, Object?>{}});
      expect(c.friendlyName, 'SomeQuery');
      expect(c.toString(), 'HookCapture(status: 200)');
    });

    test('a JSON string payload is accepted', () {
      final m = parseHookMessage([jsonEncode(payload())], pageOrigin: okOrigin);
      expect(m, isA<HookCapture>());
    });

    test('bad friendly names are not kept', () {
      final m = parseHookMessage([
        payload(override: {'friendlyName': 'a b;c'}),
      ], pageOrigin: okOrigin) as HookCapture;
      expect(m.friendlyName, isNull);
    });

    test('origin and shape drops', () {
      HookDropReason? why(List<Object?> args, {String origin = okOrigin}) {
        final m = parseHookMessage(args, pageOrigin: origin);
        return m is HookDropped ? m.reason : null;
      }

      expect(
        why([payload()], origin: 'https://evil.test'),
        HookDropReason.origin,
      );
      expect(
        why([
          payload(override: {'origin': 'https://evil.test'}),
        ]),
        HookDropReason.origin,
      );
      expect(
        why([
          payload(override: {'origin': null}),
        ]),
        HookDropReason.origin,
      );
      expect(
        why([
          payload(override: {'url': 'http://www.instagram.com/x'}),
        ]),
        HookDropReason.origin,
      );
      expect(
        why([
          payload(override: {'url': 'https://evil.test/x'}),
        ]),
        HookDropReason.origin,
      );
      expect(
        why([
          payload(override: {'body': 'not json'}),
        ]),
        HookDropReason.malformed,
      );
      expect(
        why([
          payload(override: {'body': null}),
        ]),
        HookDropReason.malformed,
      );
      expect(
        why([
          payload(override: {'status': '200'}),
        ]),
        HookDropReason.malformed,
      );
      expect(
        why([
          payload(override: {'type': 'other'}),
        ]),
        HookDropReason.malformed,
      );
      expect(
        why([
          payload(override: {'body': 'x' * (maxHookBodyLength + 1)}),
        ]),
        HookDropReason.malformed,
      );
      expect(why(const []), HookDropReason.malformed);
      expect(why(const ['nope']), HookDropReason.malformed);
    });

    test('a blocked notice needs a clean name', () {
      Object? m(String name) => parseHookMessage([
        {'type': 'blocked', 'friendlyName': name, 'origin': okOrigin},
      ], pageOrigin: okOrigin);
      expect(m('PolarisStoriesV3SeenMutation'), isA<HookBlocked>());
      expect(m('bad name'), isA<HookDropped>());
    });

    test('request secrets are kept in the capture, not in toString', () {
      final c = parseHookMessage([
        payload(
          override: {
            'request': {
              'docId': fakeDocId,
              'tokens': {'fb_dtsg': fakeDtsg},
            },
          },
        ),
      ], pageOrigin: okOrigin) as HookCapture;
      expect(c.docId, fakeDocId);
      expect(c.tokens, {'fb_dtsg': fakeDtsg});
      expect('$c', isNot(contains(fakeDtsg)));
    });
  });

  group('PageHookConfig', () {
    test('prelude is valid JSON for the hook', () {
      final p = PageHookConfig().prelude();
      final json = p.substring(p.indexOf('=') + 1).trim();
      final cfg = jsonDecode(json.substring(0, json.length - 1)) as Map;
      expect(cfg['includeBody'], true);
      expect(cfg['includeRequestSecrets'], true);
      expect(cfg['handler'], pageHookHandlerName);
      expect(cfg['blockedFriendlyNames'], ['PolarisStoriesV3SeenMutation']);
    });

    test('compose puts the config before the hook source', () {
      final s = PageHookConfig().compose('/*HOOK*/');
      expect(
        s.indexOf('__STORIZE_HOOK_CONFIG'),
        lessThan(s.indexOf('/*HOOK*/')),
      );
    });
  });

  group('DOM last resort', () {
    test('parseDomMedia keeps https CDN URLs only', () {
      final m = parseDomMedia(loadPage('dom_result.json'));
      expect(m, hasLength(2));
      expect(m.first.isVideo, isFalse);
      expect('$m', isNot(contains('fbcdn')));
    });

    test('a JSON string, junk and non-lists are handled', () {
      expect(
        parseDomMedia(
          File('test/fixtures/page/dom_result.json').readAsStringSync(),
        ),
        hasLength(2),
      );
      expect(parseDomMedia('not json'), isEmpty);
      expect(parseDomMedia(5), isEmpty);
      expect(parseDomMedia(null), isEmpty);
    });

    test('the script is read-only', () {
      for (final w in [
        '.click(',
        'scroll',
        'dispatchEvent',
        'fetch(',
        '.play(',
      ]) {
        expect(domCollectScript, isNot(contains(w)), reason: w);
      }
    });
  });
}
