String formatPropertyName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final formatted = trimmed
      .split(RegExp(r'\s+'))
      .map(_formatPropertyWord)
      .join(' ');
  return formatted.replaceFirst('Nh\u00E0 Tr\u1ECD', 'Nh\u00E0 tr\u1ECD');
}

String formatTopBarTitle(String value) {
  return value.trim();
}

/// Formats a user-facing calendar date without changing any API/date keys.
String formatDateVN(DateTime? value, {String fallback = 'Chưa cập nhật'}) {
  if (value == null) return fallback;
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

/// Formats a user-facing timestamp. API serialization must keep using ISO.
String formatDateTimeVN(DateTime? value, {String fallback = 'Chưa cập nhật'}) {
  if (value == null) return fallback;
  return '${formatDateVN(value, fallback: fallback)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String formatTimeVN(DateTime? value, {String fallback = 'Chưa cập nhật'}) {
  if (value == null) return fallback;
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String _formatPropertyWord(String word) {
  if (word.isEmpty) return word;
  final hasLetter = word.toLowerCase() != word.toUpperCase();
  if (!hasLetter) return word;

  final tail = word.length > 1 ? word.substring(1) : '';
  final hasOddCasing = word == word.toUpperCase() || tail != tail.toLowerCase();
  if (!hasOddCasing) return word;

  final lower = word.toLowerCase();
  if (lower.length == 1) return lower.toUpperCase();
  return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
}
