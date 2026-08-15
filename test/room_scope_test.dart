import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/home/current_room_service.dart';
import 'package:hdbhms_mobile/utils/room_scope.dart';

class _RoomsService extends LeaseContractService {
  const _RoomsService(this.rooms);

  final List<ActiveRoomItem> rooms;

  @override
  Future<List<ActiveRoomItem>> fetchMyActiveRooms() async => rooms;
}

ActiveRoomItem _room(int roomId, int contractId) => ActiveRoomItem(
  contractId: contractId,
  contractCode: 'HD-$contractId',
  roomId: roomId,
  roomCode: '$roomId',
  roomName: 'Phòng $roomId',
  propertyName: 'Hải Đăng',
);

void main() {
  test('explicit Room 103 remains resolved with three active rooms', () async {
    final scope = await resolveRoomScope(
      roomId: 103,
      roomCode: '103',
      currentRoomService: CurrentRoomService(
        leaseContractService: _RoomsService([
          _room(101, 201),
          _room(102, 202),
          _room(103, 203),
        ]),
      ),
    );

    expect(scope.roomId, 103);
    expect(scope.roomCode, '103');
    expect(scope.isAmbiguous, isFalse);
  });

  test(
    'unscoped three-room write context is ambiguous, never Room 101',
    () async {
      final scope = await resolveRoomScope(
        currentRoomService: CurrentRoomService(
          leaseContractService: _RoomsService([
            _room(101, 201),
            _room(102, 202),
            _room(103, 203),
          ]),
        ),
      );

      expect(scope.hasRoom, isFalse);
      expect(scope.isAmbiguous, isTrue);
      expect(scope.roomId, isNot(101));
    },
  );
}
