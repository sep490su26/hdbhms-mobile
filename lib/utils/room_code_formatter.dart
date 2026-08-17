/// Formats a room code without duplicating its built-in room prefix.
///
/// For example, `P.203` remains `P.203`, while a plain `203` becomes
/// `Phòng 203` in sentence-style UI.
String formatRoomCode(String roomCode, {String emptyLabel = 'Phòng'}) {
  final normalized = roomCode.trim();
  if (normalized.isEmpty) return emptyLabel;
  final includesRoomPrefix = RegExp(
    r'^(p\.?\s*|phòng\s+)',
    caseSensitive: false,
  ).hasMatch(normalized);
  return includesRoomPrefix ? normalized : 'Phòng $normalized';
}
