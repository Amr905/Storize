// T-041 mode selection of the history operations in InstagramPlatform.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

const _schema = SchemaChanged('doc_id:ZZFAKE');

({
  InstagramPlatform platform,
  FakeMode direct,
  FakeMode page,
  List<String> calls,
})
_rig({SeenGuard? guard}) {
  final calls = <String>[];
  final direct = FakeMode('direct', calls);
  final page = FakeMode('page', calls);
  final platform = InstagramPlatform(
    direct: direct,
    page: page,
    media: CdnMediaOpener(http: FakeCdnHttp((_, _) => throw StateError('x'))),
    seenGuard: guard ?? SeenGuard(),
    log: FakeDiagnosticLog(),
    clock: FakeClock(),
  );
  return (platform: platform, direct: direct, page: page, calls: calls);
}

void main() {
  test('direct Ok: page mode is never touched', () async {
    final r = _rig();
    await r.platform.fetchPostPage(
      'u',
      policy: ExtractionPolicy.directThenPage,
    );
    await r.platform.fetchHighlights(
      'u',
      policy: ExtractionPolicy.directThenPage,
    );
    await r.platform.fetchHighlightItems([
      'h',
    ], policy: ExtractionPolicy.directThenPage);
    expect(r.calls.every((c) => c.startsWith('direct.')), isTrue);
  });

  test(
    'SchemaChanged falls back to page mode only under directThenPage',
    () async {
      final r = _rig();
      r.direct
        ..postPage = ((_) => const Err(_schema))
        ..highlights = (() => const Err(_schema));
      final a = await r.platform.fetchPostPage(
        'u',
        policy: ExtractionPolicy.directOnly,
        cursor: 'c',
      );
      expect(a.failureOrNull, isA<SchemaChanged>());
      expect(r.calls, ['direct.fetchPostPage']);
      r.calls.clear();
      await r.platform.fetchPostPage(
        'u',
        policy: ExtractionPolicy.directThenPage,
        cursor: 'c',
      );
      await r.platform.fetchHighlights(
        'u',
        policy: ExtractionPolicy.directThenPage,
      );
      expect(r.calls, [
        'direct.fetchPostPage',
        'page.fetchPostPage',
        'direct.fetchHighlights',
        'page.fetchHighlights',
      ]);
    },
  );

  test('a rate limit from direct never reaches page mode', () async {
    final r = _rig();
    r.direct.highlightItems = (_) => Err(RateLimited(null));
    final x = await r.platform.fetchHighlightItems([
      'h',
    ], policy: ExtractionPolicy.directThenPage);
    expect(x.failureOrNull, isA<RateLimited>());
    expect(r.calls, ['direct.fetchHighlightItems']);
  });

  test('page-mode highlight items load one id per page, in order', () async {
    final r = _rig();
    r.direct.highlightItems = (_) => const Err(_schema);
    final seen = <List<String>>[];
    r.page.highlightItems = (ids) {
      seen.add(ids);
      return Ok({ids.single: const <RemoteContent>[]});
    };
    final out = await r.platform.fetchHighlightItems([
      'a',
      'b',
    ], policy: ExtractionPolicy.directThenPage);
    expect(out.valueOrNull!.keys, ['a', 'b']);
    expect(seen, [
      ['a'],
      ['b'],
    ]);
  });
}
