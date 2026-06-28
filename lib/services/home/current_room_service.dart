import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';

class CurrentRoomService {
  const CurrentRoomService({
    LeaseContractService? leaseContractService,
  }) : _leaseContractService = leaseContractService;

  final LeaseContractService? _leaseContractService;

  LeaseContractService get _service =>
      _leaseContractService ?? const LeaseContractService();

  Future<CurrentRentedRoom> getCurrentRentedRoom() async {
    final rooms = await _service.fetchMyActiveRooms();
    if (rooms.isEmpty) {
      throw const LeaseContractNotFoundException();
    }

    final room = rooms.firstWhere(
      (item) => item.roomId > 0,
      orElse: () => rooms.first,
    );

    if (room.roomId <= 0) {
      throw const LeaseContractException('Không tìm thấy phòng đang thuê');
    }

    return CurrentRentedRoom(
      id: room.roomId,
      roomCode: room.roomCode,
    );
  }
}