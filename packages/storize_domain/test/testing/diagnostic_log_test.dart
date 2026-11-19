import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:test/test.dart';

void main() {
  test('records entries in order with error and stack', () {
    final log = FakeDiagnosticLog();
    final stack = StackTrace.current;
    log
      ..log(LogLevel.info, 'a', 'one')
      ..log(LogLevel.error, 'b', 'two', error: StateError('x'), stack: stack);

    expect(log.entries.map((e) => e.message), ['one', 'two']);
    expect(log.entries.last.error, isA<StateError>());
    expect(log.entries.last.stack, same(stack));
    expect(log.at(LogLevel.error), hasLength(1));
    expect(log.at(LogLevel.warn), isEmpty);
  });

  test('entries view is unmodifiable and clear works', () {
    final log = FakeDiagnosticLog()..log(LogLevel.debug, 't', 'm');
    expect(() => log.entries.add(log.entries.first), throwsUnsupportedError);
    log.clear();
    expect(log.entries, isEmpty);
  });

  test('entry toString shows level, tag and message only', () {
    const e = FakeLogEntry(LogLevel.warn, 'tag', 'msg');
    expect(e.toString(), 'warn [tag] msg');
  });
}
