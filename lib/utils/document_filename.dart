String buildDocumentFilename({
  required String documentType,
  String? roomCode,
  DateTime? date,
}) {
  final type = _sanitizeFilenamePart(documentType, 'DOC').toUpperCase();
  final room = _withRoomPrefix(_sanitizeFilenamePart(roomCode, 'Phong-X'));
  return '${type}_${room}_${_formatFilenameDate(date)}.pdf';
}

String resolvePdfDownloadFilename({
  String? contentDisposition,
  String? suggestedFilename,
  String fallback = 'tai-lieu.pdf',
}) {
  if (suggestedFilename != null && suggestedFilename.trim().isNotEmpty) {
    return sanitizeDownloadFilename(suggestedFilename, fallback);
  }
  final headerFilename = filenameFromContentDisposition(contentDisposition);
  if (headerFilename.isNotEmpty) {
    return sanitizeDownloadFilename(headerFilename, fallback);
  }
  return fallback;
}

String filenameFromContentDisposition(String? headerValue) {
  if (headerValue == null || headerValue.trim().isEmpty) return '';

  final filenameStarMatch = RegExp(
    r"filename\*\s*=\s*(?:UTF-8'')?([^;]+)",
    caseSensitive: false,
  ).firstMatch(headerValue);
  if (filenameStarMatch != null) {
    return _decodeHeaderFilename(filenameStarMatch.group(1) ?? '');
  }

  final filenameMatch = RegExp(
    r'filename\s*=\s*("[^"]+"|[^;]+)',
    caseSensitive: false,
  ).firstMatch(headerValue);
  if (filenameMatch == null) return '';
  return _stripQuotes(filenameMatch.group(1) ?? '');
}

String sanitizeDownloadFilename(String value, String fallback) {
  final sanitized = value.trim().replaceAll(RegExp(r'[/\\:*?"<>|#]'), '');
  if (sanitized.isEmpty) return fallback;
  return sanitized.toLowerCase().endsWith('.pdf')
      ? sanitized
      : '$sanitized.pdf';
}

String _decodeHeaderFilename(String value) {
  final stripped = _stripQuotes(value);
  try {
    return Uri.decodeComponent(stripped);
  } on FormatException {
    return stripped;
  }
}

String _stripQuotes(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

String _formatFilenameDate(DateTime? date) {
  if (date == null) return 'Chua-Ro-Ngay';
  return '${date.day.toString().padLeft(2, '0')}_'
      '${date.month.toString().padLeft(2, '0')}_'
      '${date.year.toString().padLeft(4, '0')}';
}

String _sanitizeFilenamePart(String? value, String fallback) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return fallback;
  final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  return sanitized.isEmpty ? fallback : sanitized;
}

String _withRoomPrefix(String roomCode) {
  if (roomCode.startsWith('Phong')) return roomCode;
  if (roomCode.toLowerCase().startsWith('p')) {
    return 'P${roomCode.substring(1)}';
  }
  return 'P$roomCode';
}
