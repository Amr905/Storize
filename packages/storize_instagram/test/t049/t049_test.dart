// T-049: tokens and providers from discovery or captures, the pre-send guard,
// the `for (;;);` and missing-variable classification, log hygiene.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _pv = '__relay_internal__pv__PolarisZzFakeEnabled';
const _posts = 'PolarisProfilePostsQuery';
const _stories = 'PolarisStoriesV3ReelPageStandaloneQuery';

DiscoveredOp _op({
  String name = _posts,
  Map<String, Object> provided = const {},
  List<String> args = const [],
  bool loaded = false,
}) => DiscoveredOp(
  name: name,
  docId: '11111111111111111',
  provided: provided,
  args: args,
  loaded: loaded,
);

PageDiscovery _disc({DiscoveryStore? store}) =>
    PageDiscovery(clock: FakeClock(), store: store, accountId: 1);

IgReply _shield(int code) => IgReply(
  status: 200,
  json: <String, Object?>{'__ar': 1, 'error': code, 'errorSummary': 'x'},
  shielded: true,
);

void main() {
  group('tokens: merged, never wiped by empty or partial captures', () {
    test('a capture without fb_dtsg keeps the discovered pair', () async {
      final d = _disc()
        ..recordDiscovery(
          [
            _op(provided: {_pv: true}),
          ],
          {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
        )
        ..record(
          friendlyName: _posts,
          docId: '22222222222222222',
          tokens: {'lsd': 'ZZFAKE_newer_lsd', 'av': '1', 'empty': ''},
        );
      final t = await d.tokens();
      expect(t!['fb_dtsg'], fakeDtsg);
      expect(t['lsd'], 'ZZFAKE_newer_lsd');
      expect(t.containsKey('empty'), isFalse);
    });

    test('empty values and empty maps never replace good tokens', () async {
      final d = _disc()
        ..recordDiscovery(const [], {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd})
        ..recordDiscovery(const [], {'fb_dtsg': '', 'lsd': ''})
        ..record(friendlyName: null, docId: null, tokens: const {});
      expect(await d.tokens(), {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd});
    });

    test(
      'each token is merged on its own',
      () async {
        final d = _disc()..recordDiscovery(const [], {'fb_dtsg': fakeDtsg});
        expect(pageTokensComplete(await d.tokens()), isFalse);
        d.record(friendlyName: null, docId: null, tokens: {'lsd': fakeLsd});
        expect(await d.tokens(), {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd});
        expect(pageTokensComplete(await d.tokens()), isTrue);
      },
    );

    test('persisted tokens are merged key-wise, not overwritten', () async {
      final store = InMemoryDiscoveryStore();
      final a = _disc(store: store)
        ..recordDiscovery(const [], {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd});
      await a.flush();
      final b = _disc(store: store)
        ..record(friendlyName: null, docId: null, tokens: {'av': '1'});
      await b.flush();
      final c = _disc(store: store);
      final t = await c.tokens();
      expect(t!['fb_dtsg'], fakeDtsg);
      expect(t['lsd'], fakeLsd);
      expect(t['av'], '1');
    });

    test('forgetTokens clears memory and the store', () async {
      final store = InMemoryDiscoveryStore();
      final a = _disc(store: store)
        ..recordDiscovery(const [], {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd});
      await a.flush();
      await a.forgetTokens();
      expect(await a.tokens(), isNull);
      expect(await _disc(store: store).tokens(), isNull);
    });

    test('tokens come from either source and say which', () async {
      final d = _disc()
        ..recordDiscovery(
          const [],
          {'fb_dtsg': fakeDtsg},
          tokenSources: {'fb_dtsg': 'module'},
        )
        ..record(friendlyName: null, docId: null, tokens: {'lsd': fakeLsd});
      expect(
        d.describe(),
        'provided=none tokens=dtsg:yes(module),lsd:yes(capture)',
      );
      expect(d.describe(), isNot(contains(fakeDtsg)));
      expect(d.describe(), isNot(contains(fakeLsd)));
    });
  });

  group('providers: from modules or captured variables', () {
    test('captured providers fill a shape the modules did not give', () async {
      final d = _disc()
        ..record(
          friendlyName: _posts,
          docId: '33333333333333333',
          tokens: const {},
          provided: {_pv: true},
          args: ['username', 'data'],
        );
      final shape = await d.shapeFor(GraphqlQuery.posts);
      expect(shape!.provided, {_pv: true});
      expect(shape.args, ['username', 'data']);
      expect(shape.isKnown, isTrue);
    });

    test('module values win over captured ones, both are kept', () async {
      final d = _disc()
        ..record(
          friendlyName: _posts,
          docId: '33333333333333333',
          tokens: const {},
          provided: {_pv: false, '${_pv}2': 1},
        )
        ..recordDiscovery([
          _op(provided: {_pv: true}, args: ['username']),
        ], const {});
      final shape = (await d.shapeFor(GraphqlQuery.posts))!;
      expect(shape.provided, {_pv: true, '${_pv}2': 1});
      expect(shape.args, ['username']);
    });

    test('a later capture does not replace module arguments', () async {
      final d = _disc()
        ..recordDiscovery([
          _op(provided: {_pv: true}, args: ['username']),
        ], const {})
        ..record(
          friendlyName: _posts,
          docId: '33333333333333333',
          tokens: const {},
          args: ['username', 'data'],
        );
      expect((await d.shapeFor(GraphqlQuery.posts))!.args, ['username']);
    });

    test('merging across discoveries keeps what was found before', () async {
      final d = _disc()
        ..recordDiscovery([
          _op(provided: {_pv: true}),
        ], const {})
        ..recordDiscovery([
          _op(args: ['username']),
        ], const {});
      final shape = (await d.shapeFor(GraphqlQuery.posts))!;
      expect(shape.provided, {_pv: true});
      expect(shape.args, ['username']);
    });

    test('a shape is known with providers, args or a loaded module', () {
      expect(const QueryShape().isKnown, isFalse);
      expect(const QueryShape(provided: {_pv: true}).isKnown, isTrue);
      expect(const QueryShape(args: ['a']).isKnown, isTrue);
      expect(const QueryShape(loaded: true).isKnown, isTrue);
    });

    test('providers survive the store round trip (loaded flag too)', () async {
      final store = InMemoryDiscoveryStore();
      final a = _disc(store: store)
        ..recordDiscovery([_op(loaded: true)], const {});
      await a.flush();
      final shape = await _disc(store: store).shapeFor(GraphqlQuery.posts);
      expect(shape!.loaded, isTrue);
      expect(shape.isKnown, isTrue);
    });

    test(
      'a capture without any variables info leaves the shape unknown',
      () async {
        final d = _disc()
          ..record(friendlyName: _posts, docId: '3333333', tokens: const {});
        expect(await d.shapeFor(GraphqlQuery.posts), isNull);
      },
    );

    test('forgetProviders drops the shape, not the doc_id', () async {
      final store = InMemoryDiscoveryStore();
      final d = _disc(store: store)
        ..recordDiscovery([
          _op(provided: {_pv: true}),
        ], const {});
      await d.flush();
      await d.forgetProviders(GraphqlQuery.posts);
      expect(await d.docIdFor(GraphqlQuery.posts), '11111111111111111');
      expect(await d.shapeFor(GraphqlQuery.posts), isNull);
      expect(
        await _disc(store: store).shapeFor(GraphqlQuery.posts),
        isNull,
        reason: 'gone from the store too',
      );
    });
  });

  group('pre-send guard', () {
    Future<(Result<Timeline>, int)> timeline(PageDiscovery d) async {
      var sent = 0;
      final t = GraphqlTransport(docIds: d, tokens: d);
      final r = await t.timeline('1', (req) async {
        sent++;
        return const Ok(<String, Object?>{});
      }, usernameHint: 'zz_user');
      return (r, sent);
    }

    test('no tokens: SchemaChanged(page_tokens), nothing sent', () async {
      final d = _disc()
        ..recordDiscovery([
          _op(provided: {_pv: true}),
        ], const {});
      final (r, sent) = await timeline(d);
      expect(r.failureOrNull, const SchemaChanged('page_tokens'));
      expect(sent, 0);
    });

    test('only fb_dtsg or only lsd: page_tokens, nothing sent', () async {
      for (final t in [
        {'fb_dtsg': fakeDtsg},
        {'lsd': fakeLsd},
      ]) {
        final d = _disc()
          ..recordDiscovery([
            _op(provided: {_pv: true}),
          ], t);
        final (r, sent) = await timeline(d);
        expect(r.failureOrNull, const SchemaChanged('page_tokens'));
        expect(sent, 0);
      }
    });

    test(
      'tokens but unknown providers: SchemaChanged(providers), nothing sent',
      () async {
        final d = _disc()
          ..record(
            friendlyName: _posts,
            docId: '3333333',
            tokens: {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
          );
        final (r, sent) = await timeline(d);
        expect(r.failureOrNull, const SchemaChanged('providers'));
        expect(sent, 0);
      },
    );

    test('providers from captured variables allow the request', () async {
      final d = _disc()
        ..record(
          friendlyName: _posts,
          docId: '3333333',
          tokens: {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
          provided: {_pv: true},
          args: ['username', 'data'],
        );
      IgRequest? seen;
      final t = GraphqlTransport(docIds: d, tokens: d);
      await t.timeline('1', (req) async {
        seen = req;
        return const Ok(<String, Object?>{});
      }, usernameHint: 'zz_user');
      expect(variablesOf(seen!)[_pv], isTrue);
      expect(seen!.form!['fb_dtsg'], fakeDtsg);
    });

    test('the fallback reports the missing piece without a request', () async {
      final d = _disc();
      final f = FallbackTransport(docIds: d, tokens: d);
      d.record(
        friendlyName: _posts,
        docId: '3333333',
        tokens: {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
      );
      var sent = 0;
      final r = await f.timeline('1', (req) async {
        sent++;
        return const Ok(<String, Object?>{});
      }, usernameHint: 'zz_user');
      expect(r.failureOrNull, const SchemaChanged('providers'));
      expect(sent, 0);
    });

    test('a providers failure from Instagram drops the shape, keeps the '
        'doc_id; a page_tokens failure drops the tokens', () async {
      final d = _disc()
        ..recordDiscovery(
          [
            _op(provided: {_pv: true}),
          ],
          {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
        );
      final t = GraphqlTransport(docIds: d, tokens: d);
      var r = await t.timeline(
        '1',
        (req) async => const Err(SchemaChanged('providers')),
        usernameHint: 'zz_user',
      );
      expect(r.failureOrNull, const SchemaChanged('providers'));
      expect(await d.shapeFor(GraphqlQuery.posts), isNull);
      expect(await d.docIdFor(GraphqlQuery.posts), isNotNull);
      expect(await d.tokens(), isNotNull);
      r = await GraphqlTransport(docIds: d, tokens: d).timeline(
        '1',
        (req) async => const Err(SchemaChanged('page_tokens')),
        usernameHint: 'zz_user',
      );
      // Providers are gone, so this one stops before sending.
      expect(r.failureOrNull, const SchemaChanged('providers'));
      d.recordDiscovery([
        _op(provided: {_pv: true}),
      ], const {});
      r = await t.timeline(
        '1',
        (req) async => const Err(SchemaChanged('page_tokens')),
        usernameHint: 'zz_user',
      );
      expect(r.failureOrNull, const SchemaChanged('page_tokens'));
      expect(await d.tokens(), isNull, reason: 'stale tokens dropped');
    });
  });

  group('failure classification', () {
    const c = FailureClassifier();

    test('for (;;); with the login code is SessionInvalid', () {
      expect(
        c.classify(_shield(1357001)),
        const SessionInvalid(SessionReason.loginRequired),
      );
    });

    test('for (;;); with any other code is stale tokens', () {
      expect(c.classify(_shield(1357004)), const SchemaChanged('page_tokens'));
      expect(c.classify(_shield(1)), const SchemaChanged('page_tokens'));
    });

    test('an error body that is not shielded keeps its old handling', () {
      expect(
        c.classify(
          const IgReply(status: 200, json: {'error': 1357004}),
        ),
        isNot(const SchemaChanged('page_tokens')),
      );
    });

    test('missing_required_variable_value is SchemaChanged(providers)', () {
      final f = c.classify(
        const IgReply(
          status: 200,
          json: {
            'errors': [
              {
                'message':
                    'A server error missing_required_variable_value occured',
              },
            ],
          },
        ),
      );
      expect(f, const SchemaChanged('providers'));
    });

    test('other errors[] without data are not the providers failure', () {
      final f = c.classify(
        const IgReply(
          status: 200,
          json: {
            'data': null,
            'errors': [
              {'message': 'something else'},
            ],
          },
        ),
      );
      expect(f, isNot(const SchemaChanged('providers')));
    });

    test(
      'DartIoHttp reads a for (;;); body: the JSON after it and the code',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        unawaited(
          server.forEach((req) async {
            await req.drain<void>();
            req.response
              ..headers.contentType = ContentType('text', 'javascript')
              ..write(
                'for (;;);{"__ar":1,"error":1357004,"errorSummary":"ZZFAKE"}',
              );
            await req.response.close();
          }),
        );
        final reply = await DartIoHttp().send(
          IgRequest(
            method: IgMethod.get,
            uri: Uri.parse('http://127.0.0.1:${server.port}/x'),
          ),
        );
        expect(reply.shielded, isTrue);
        expect(reply.fbError, 1357004);
        expect(
          const FailureClassifier().classify(reply),
          const SchemaChanged('page_tokens'),
        );
        expect('$reply', isNot(contains('ZZFAKE')));
      },
    );
  });

  group('direct extractor: classification and log hygiene', () {
    test(
      'a for (;;); reply logs fb_error=<code> only and drops the tokens',
      () async {
        final d = _disc()
          ..recordDiscovery(
            [
              _op(name: _stories, provided: {_pv: true}),
            ],
            {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
          );
        final rig = Rig(
          transport: GraphqlTransport(docIds: d, tokens: d),
          responder: (_) => _shield(1357004),
        );
        final r = await rig.run(
          rig.extractor.fetchStories(['user_1']),
        );
        expect(r.failureOrNull, const SchemaChanged('page_tokens'));
        final line = rig.log.entries
            .map((e) => e.message)
            .singleWhere((m) => m.contains('failure=SchemaChanged'));
        expect(line, contains('where=page_tokens'));
        expect(line, contains('fb_error=1357004'));
        expect(line, isNot(contains('ZZFAKE')));
        expect(line, isNot(contains('errorSummary')));
        expect(await d.tokens(), isNull);
      },
    );

    test(
      'missing_required_variable logs the fixed reason, drops providers',
      () async {
        final d = _disc()
          ..recordDiscovery(
            [
              _op(name: _stories, provided: {_pv: true}),
            ],
            {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
          );
        final rig = Rig(
          transport: GraphqlTransport(docIds: d, tokens: d),
          responder: (_) => const IgReply(
            status: 200,
            json: {
              'errors': [
                {
                  'message':
                      'A server error missing_required_variable_value ZZFAKE',
                },
              ],
            },
          ),
        );
        final r = await rig.run(
          rig.extractor.fetchStories(['user_1']),
        );
        expect(r.failureOrNull, const SchemaChanged('providers'));
        final lines = rig.log.entries.map((e) => e.message).join('\n');
        expect(lines, contains('where=providers'));
        expect(lines, isNot(contains('ZZFAKE')));
        expect(lines, isNot(contains(fakeDtsg)));
        expect(await d.shapeFor(GraphqlQuery.stories), isNull);
      },
    );

    test('a login code is SessionInvalid through the extractor', () async {
      final d = _disc()
        ..recordDiscovery(
          [
            _op(name: _stories, provided: {_pv: true}),
          ],
          {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
        );
      final rig = Rig(
        transport: GraphqlTransport(docIds: d, tokens: d),
        responder: (_) => _shield(1357001),
      );
      final r = await rig.run(
        rig.extractor.fetchStories(['user_1']),
      );
      expect(r.failureOrNull, isA<SessionInvalid>());
    });
  });

  group('capture messages', () {
    const origin = 'https://www.instagram.com';
    Map<String, Object?> cap(Object? request) => {
      'url': '$origin/api/graphql',
      'status': 200,
      'bodyLength': 2,
      'topLevelKeys': ['data'],
      'origin': origin,
      'via': 'fetch',
      'friendlyName': _posts,
      'body': '{}',
      'request': request,
    };

    test('provided scalars, args and the variables flag are read', () {
      final m = parseHookMessage([
        cap({
          'docId': '12345678',
          'tokens': {'lsd': 'x'},
          'provided': {
            _pv: true,
            'bad key': 1,
            '${_pv}o': {'no': 1},
          },
          'args': ['username', 'Bad-Name'],
          'vars': true,
        }),
      ], pageOrigin: origin) as HookCapture;
      expect(m.provided, {_pv: true});
      expect(m.args, ['username']);
      expect(m.variablesSeen, isTrue);
    });

    test('a doc_id of a wrong shape is counted as rejected, never kept', () {
      final m = parseHookMessage([
        cap({'docId': '12345678\n', 'tokens': <String, String>{}}),
      ], pageOrigin: origin) as HookCapture;
      expect(m.docId, isNull);
      expect(m.docIdRejected, isTrue);
    });

    test('a discovery message carries token sources and the loaded flag', () {
      final m = parseHookMessage([
        {
          'type': 'discovery',
          'origin': origin,
          'ops': [
            {
              'name': _posts,
              'docId': '12345678',
              'provided': <String, Object>{},
              'args': <String>[],
              'loaded': true,
              'src': 'capture',
            },
          ],
          'tokens': {'fb_dtsg': 'a', 'lsd': 'b'},
          'tokenSources': {'fb_dtsg': 'module', 'lsd': 'capture'},
        },
      ], pageOrigin: origin) as HookDiscovery;
      expect(m.ops.single.loaded, isTrue);
      expect(m.ops.single.source, 'capture');
      expect(m.tokenSources, {'fb_dtsg': 'module', 'lsd': 'capture'});
    });
  });
}
