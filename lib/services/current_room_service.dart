import '../models/maintenance_ticket_model.dart';
import 'lease_contract_service.dart';

class CurrentRoomService {
  const CurrentRoomService({
    this.leaseContractService = const LeaseContractService(),
  });

  static const _activeStatuses = {
    'ACTIVE',
    'EXPIRING_SOON',
    'TERMINATION_PENDING',
  };

  final LeaseContractService leaseContractService;

  Future<CurrentRentedRoom> getCurrentRentedRoom() async {
    final rooms = await leaseContractService.fetchMyActiveRooms();
    final activeRooms = rooms
        .where((room) {
          final status = room.contractStatus.trim().toUpperCase();
          return status.isEmpty || _activeStatuses.contains(status);
        })
        .toList(growable: false);

    if (activeRooms.isEmpty) {
      throw const LeaseContractNotFoundException();
    }

    final room = activeRooms.first;
    return CurrentRentedRoom(id: room.roomId, roomCode: room.roomCode);
  }
}
