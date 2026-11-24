import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/mapper/mapper.dart';

void main() {
  test('round trip with boundary pks and an Instagram cursor', () {
    final c = PostCursor(
      takenAt: DateTime.utc(2030),
      igCursor: 'ZZFAKE_c',
      boundaryPks: const {'a', 'b'},
    );
    final back = PostCursor.parse(c.encode())!;
    expect(back.igCursor, 'ZZFAKE_c');
    expect(back.boundaryPks, {'a', 'b'});
    expect(back.takenAt, c.takenAt);
  });

  test('an old three-part cursor parses without boundary pks', () {
    expect(PostCursor.parse('v1|1800000000|x')!.boundaryPks, isEmpty);
  });

  test('out-of-range seconds are refused (F3)', () {
    expect(PostCursor.parse('v1|9223372036854775807|x'), isNull);
    expect(PostCursor.parse('v1|-5|x'), isNull);
  });
}
