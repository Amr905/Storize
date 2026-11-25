// T-051: the lease wrapper must not hide the in-page script runner.
// Device log 2026-11-25: `[inpage] unavailable why=no_script_runner`
// because `LeaseHoldingPageDriver` wrapped the real session.

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';

final class _RunnerSession implements PageSession, InPageScriptRunner {
  final calls = <String>[];
  @override
  Stream<PageEvent> get events => const Stream.empty();
  @override
  Future<void> load(Uri url) async {}
  @override
  Future<Object?> collectDomMedia() async => null;
  @override
  Future<void> scrollDown() async {}
  @override
  Future<void> clearData() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<Object?> callAsync(String body, Map<String, Object?> args) async {
    calls.add(body);
    return {'ok': true};
  }
}

final class _PlainSession implements PageSession {
  @override
  Stream<PageEvent> get events => const Stream.empty();
  @override
  Future<void> load(Uri url) async {}
  @override
  Future<Object?> collectDomMedia() async => null;
  @override
  Future<void> scrollDown() async {}
  @override
  Future<void> clearData() async {}
  @override
  Future<void> dispose() async {}
}

final class _Driver implements PageDriver {
  _Driver(this.session);
  final PageSession session;
  @override
  Future<PageSession> open(PageSessionConfig config) async => session;
}

const _config = PageSessionConfig(
  cookies: {},
  userAgent: 'ZZFAKE',
  hookSource: '',
  handlerName: 'h',
  allowedOrigins: {},
);

void main() {
  GovernorWebViewLease lease() {
    final clock = FakeClock();
    return GovernorWebViewLease(
      repo: FakeGovernorLeaseRepo(clock),
      clock: clock,
      instanceId: 'a',
      log: FakeDiagnosticLog(),
    );
  }

  test(
    'the wrapped session is still a script runner and passes calls on',
    () async {
      final inner = _RunnerSession();
      final s = await LeaseHoldingPageDriver(
        _Driver(inner),
        lease(),
      ).open(_config);
      expect(s, isA<InPageScriptRunner>());
      final r = await (s as InPageScriptRunner).callAsync('return 1;', {});
      expect(r, {'ok': true});
      expect(inner.calls, ['return 1;']);
      await s.dispose();
    },
  );

  test('a wrapped session without a runner fails the call clearly', () async {
    final s = await LeaseHoldingPageDriver(
      _Driver(_PlainSession()),
      lease(),
    ).open(_config);
    expect(
      () => (s as InPageScriptRunner).callAsync('x', {}),
      throwsUnsupportedError,
    );
    await s.dispose();
  });
}
