// T-047 QA: alias safety, variables compatibility, log hygiene.
// Synthetic values only.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

void main() {
  group('alias safety', () {
    test('unrelated names holding Stories do not match stories', () {
      for (final n in [
        'PolarisStoriesTrayQuery',
        'PolarisFeedStoriesBarQuery',
        'StoriesSettingsQuery',
        'PolarisStoriesV3ReelsTrayQuery',
        'PolarisStoriesV3SeenMutation',
        'PolarisStoriesV3ReelSeenMutation',
      ]) {
        expect(GraphqlQuery.stories.matchesName(n), isFalse, reason: n);
      }
    });

    test('a highlights tray name matches only highlights', () {
      const n = 'PolarisProfileHighlightsTrayContentQuery';
      expect(GraphqlQuery.highlights.matchesName(n), isTrue);
      for (final q in [
        GraphqlQuery.stories,
        GraphqlQuery.posts,
        GraphqlQuery.profile,
      ]) {
        expect(q.matchesName(n), isFalse, reason: q.name);
      }
    });

    test('recording a tray alias never fills the stories doc_id', () async {
      final d = PageDiscovery(clock: FakeClock())
        ..record(
          friendlyName: 'PolarisProfileHighlightsTrayContentQuery',
          docId: '999',
          tokens: const {},
        );
      expect(await d.docIdFor(GraphqlQuery.stories), isNull);
      expect(await d.docIdFor(GraphqlQuery.highlights), '999');
    });

    test('no name matches two queries (posts/profile/stories)', () {
      for (final n in [
        'PolarisProfilePostsTabContentQuery',
        'PolarisProfilePostsTabContentQuery_connection',
        'PolarisProfilePageContentQuery',
        'PolarisStoriesV3ReelPageStandaloneQuery',
        'PolarisProfilePageContentQuery_v2',
      ]) {
        final hits = GraphqlQuery.values.where((q) => q.matchesName(n));
        expect(hits.length, 1, reason: '$n -> ${hits.map((q) => q.name)}');
      }
    });

    test('FINDING: a _connection alias doc_id gets first-page variables '
        'without first/after', () async {
      final sent = <IgRequest>[];
      final t = GraphqlTransport(
        docIds: _Ids(),
        tokens: _Tok(),
      );
      await t.timeline('1', (r) async {
        sent.add(r);
        return const Ok(<String, Object?>{});
      }, usernameHint: 'zz_user');
      final vars =
          jsonDecode(sent.single.form!['variables']!) as Map<String, Object?>;
      // The request is sent under the exact name with a doc_id that may have
      // been learned from the paging `_connection` query.
      expect(vars.containsKey('first'), isFalse);
      expect(vars.containsKey('after'), isFalse);
    });
  });

  group('log hygiene', () {
    test('logSafeNames strips url, punctuation, unicode; keeps charset', () {
      final out = logSafeNames([
        'https://www.instagram.com/zz_user/?doc_id=123&x=y',
        'Name${String.fromCharCode(0x202E)}${String.fromCharCode(0xE9)}',
        '!!!',
        '',
      ]);
      expect(out, hasLength(2));
      for (final n in out) {
        expect(RegExp(r'^[A-Za-z0-9_]{1,60}$').hasMatch(n), isTrue);
      }
      expect(out.last, 'Name');
    });

    test('FINDING(low): an all-digit name passes through the sanitizer', () {
      expect(logSafeNames(['1234567890123456']), isEmpty);
    });
  });
}

final class _Ids implements DocIdResolver {
  @override
  Future<String?> docIdFor(GraphqlQuery query) async => 'ZZFAKE_doc';
}

final class _Tok implements PageTokenProvider {
  @override
  Future<Map<String, String>?> tokens() async => {'lsd': 'ZZFAKE_lsd'};
}
