// Test-only: lint noise from dense adversarial inputs is suppressed on purpose.
// ignore_for_file: cascade_invocations, lines_longer_than_80_chars, avoid_redundant_argument_values
// QA (T-011): APP_CRASH adversarial tests.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/log/crash_marker.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

const _s1 = 'ZZQASECRETONE9f8e7d';
const _s2 = 'ZZQASECRETTWO1a2b3c';

void main() {
  late Directory tmp;
  late CrashMarker marker;
  late FakeClock clock;
  late FakeActivityRepo repo;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storize_qa_marker_');
    marker = CrashMarker(Directory('${tmp.path}/logs'));
    clock = FakeClock(DateTime.utc(2026, 11, 19, 8));
    repo = FakeActivityRepo(clock);
  });
  tearDown(() => tmp.deleteSync(recursive: true));
  Future<List<ActivityEvent>> events() => repo.watchRecent().first;

  test('10 concurrent callers produce exactly one APP_CRASH', () async {
    marker.write(StateError('boom'), DateTime.utc(2026, 11, 19, 7));
    final results = await Future.wait([
      for (var i = 0; i < 10; i++)
        reportPendingCrash(repo, clock, marker: marker),
    ]);
    expect(results.where((r) => r).length, 1);
    final e = await events();
    expect(e.length, 1);
    expect(e.single.type, ActivityType.appCrash);
    expect(e.single.severity, Severity.error);
  });

  test(
    'two CrashMarker instances on one directory (two isolates) report once',
    () async {
      final other = CrashMarker(marker.directory);
      marker.write(StateError('boom'), DateTime.utc(2026));
      final r = await Future.wait([
        reportPendingCrash(repo, clock, marker: marker),
        reportPendingCrash(repo, clock, marker: other),
      ]);
      expect(r.where((x) => x).length, 1);
    },
  );

  test('second start after a report adds nothing', () async {
    marker.write(StateError('boom'), DateTime.utc(2026));
    expect(await reportPendingCrash(repo, clock, marker: marker), isTrue);
    expect(await reportPendingCrash(repo, clock, marker: marker), isFalse);
    expect((await events()).length, 1);
  });

  test('no marker, no activity', () async {
    expect(await reportPendingCrash(repo, clock, marker: marker), isFalse);
    expect(await events(), isEmpty);
  });

  test('marker and activity payload hold no secret from ANY line of the error', () async {
    marker.write(
      _Err(
        'first sessionid=$_s1\nCookie: a=$_s2\nhttps://scontent.cdninstagram.com/a.jpg?oh=$_s2',
      ),
      DateTime.utc(2026),
    );
    final raw = marker.file.readAsStringSync();
    expect(raw, isNot(contains(_s1)));
    expect(raw, isNot(contains(_s2)));
    expect(raw, isNot(contains('cdninstagram')));
    await reportPendingCrash(repo, clock, marker: marker);
    final payload = (await events()).single.payload.toString();
    expect(payload, isNot(contains(_s1)));
    expect(payload, isNot(contains(_s2)));
    expect(payload, isNot(contains('#0'))); // no stack trace
  });

  test(
    'secret split across the first-line cut (200 chars) leaves no fragment',
    () {
      for (var pad = 180; pad <= 205; pad++) {
        final dir = Directory('${tmp.path}/p$pad');
        final m = CrashMarker(dir);
        m.write(StateError('${'x' * pad} sessionid=$_s1'), DateTime.utc(2026));
        expect(
          m.file.readAsStringSync(),
          isNot(contains('ZZQA')),
          reason: 'pad=$pad',
        );
      }
    },
  );

  test('hostile type name / toString cannot break or inject into marker', () {
    marker.write(_Hostile(), DateTime.utc(2026));
    final info = marker.read()!;
    expect(info.type, '_Hostile');
    expect(info.summary, '');
    final m2 = CrashMarker(Directory('${tmp.path}/m2'));
    m2.write(_Err('line1\r\nsessionid=$_s1'), DateTime.utc(2026));
    expect(m2.read()!.summary, isNot(contains(_s1)));
  });

  test('first marker wins: a second write does not overwrite', () {
    marker.write(StateError('root cause'), DateTime.utc(2026, 1, 1));
    marker.write(ArgumentError('follow-on'), DateTime.utc(2026, 1, 2));
    expect(marker.read()!.type, 'StateError');
    expect(marker.read()!.summary, contains('root cause'));
  });

  test('corrupt marker still yields one APP_CRASH (type Unknown)', () async {
    marker.directory.createSync(recursive: true);
    marker.file.writeAsStringSync('{not json');
    expect(await reportPendingCrash(repo, clock, marker: marker), isTrue);
    final e = (await events()).single;
    expect(e.payload['errorType'], 'Unknown');
  });

  test(
    'tampered marker with a secret in summary is re-redacted on read',
    () async {
      marker.directory.createSync(recursive: true);
      marker.file.writeAsStringSync(
        '{"type":"X","summary":"sessionid=$_s1","at":"2026-01-01T00:00:00Z"}',
      );
      await reportPendingCrash(repo, clock, marker: marker);
      expect((await events()).single.payload.toString(), isNot(contains(_s1)));
    },
  );

  test('FINDING: error text that is only a secret-free-looking word is kept; bare token is not detectable', () {
    // Documented limit (developer note): no key means no redaction.
    marker.write(StateError(_s1), DateTime.utc(2026));
    expect(marker.file.readAsStringSync(), contains(_s1));
  });

  test('failed report restores the marker for the next start', () async {
    marker.write(StateError('boom'), DateTime.utc(2026));
    final failing = _FailingRepo();
    await expectLater(
      reportPendingCrash(failing, clock, marker: marker),
      throwsA(isA<StateError>()),
    );
    expect(marker.read(), isNotNull);
    expect(await reportPendingCrash(repo, clock, marker: marker), isTrue);
  });
}

class _Err implements Exception {
  _Err(this.m);
  final String m;
  @override
  String toString() => m;
}

class _Hostile {
  @override
  String toString() => throw StateError('nope');
}

class _FailingRepo implements ActivityRepo {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('db down');
}
