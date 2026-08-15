import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';

class CurrentRoomAmbiguousException extends LeaseContractException {
  const CurrentRoomAmbiguousException()
    : super('Không xác định được phòng đang thao tác khi có nhiều phòng.');
}

class CurrentRoomService {
  const CurrentRoomService({LeaseContractService? leaseContractService})
    : _leaseContractService = leaseContractService;

  final LeaseContractService? _leaseContractService;

  LeaseContractService get _service =>
      _leaseContractService ?? const LeaseContractService();

  Future<CurrentRentedRoom> getCurrentRentedRoom() async {
    final rooms = await _service.fetchMyActiveRooms();
    if (rooms.isEmpty) {
      throw const LeaseContractNotFoundException();
    }

    final validRooms = rooms.where((item) => item.roomId > 0).toList();
    if (validRooms.isEmpty) {
      throw const LeaseContractException('Không tìm thấy phòng đang thuê');
    }
    if (validRooms.length > 1) throw const CurrentRoomAmbiguousException();

    final room = validRooms.single;
    return CurrentRentedRoom(id: room.roomId, roomCode: room.roomCode);
  }
}
