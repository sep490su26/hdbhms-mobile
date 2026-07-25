import 'package:hdbhms_mobile/services/home/current_room_service.dart';

class RoomScope {
  const RoomScope({this.roomId, this.roomCode = ''});

  final int? roomId;
  final String roomCode;

  bool get hasRoom => (roomId ?? 0) > 0 || roomCode.trim().isNotEmpty;
}

Future<RoomScope> resolveRoomScope({
  int? roomId,
  String? roomCode,
  CurrentRoomService currentRoomService = const CurrentRoomService(),
}) async {
  final normalizedCode = roomCode?.trim() ?? '';
  if ((roomId ?? 0) > 0 || normalizedCode.isNotEmpty) {
    return RoomScope(roomId: roomId, roomCode: normalizedCode);
  }

  try {
    final current = await currentRoomService.getCurrentRentedRoom();
    return RoomScope(roomId: current.id, roomCode: current.roomCode);
  } catch (_) {
    return const RoomScope();
  }
}
