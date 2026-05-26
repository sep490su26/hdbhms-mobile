import '../models/maintenance_ticket_model.dart';

class CurrentRoomService {
  const CurrentRoomService();

  Future<CurrentRentedRoom> getCurrentRentedRoom() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    // Temporary local response until the tenant session exposes room data.
    return const CurrentRentedRoom(id: 1, roomCode: '201');
  }
}
