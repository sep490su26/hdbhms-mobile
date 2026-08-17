import 'package:hdbhms_mobile/services/home/current_room_service.dart';

class RoomScope {
  const RoomScope({this.roomId, this.roomCode = '', this.isAmbiguous = false});

  final int? roomId;
  final String roomCode;
  final bool isAmbiguous;

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
  } on CurrentRoomAmbiguousException {
    return const RoomScope(isAmbiguous: true);
  } catch (_) {
    return const RoomScope();
  }
}
