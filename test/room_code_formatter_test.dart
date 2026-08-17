import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/utils/room_code_formatter.dart';

void main() {
  test('keeps an existing room prefix and labels a plain room code', () {
    expect(formatRoomCode('P.203'), 'P.203');
    expect(formatRoomCode('p.203'), 'p.203');
    expect(formatRoomCode('203'), 'Phòng 203');
  });
}
