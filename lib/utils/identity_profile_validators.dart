String? validateIdentityDocumentNumber(String? value) {
  final number = value?.trim() ?? '';
  if (number.isEmpty) return 'Vui lòng nhập số CCCD';
  if (!RegExp(r'^\d{12}$').hasMatch(number)) {
    return 'Số CCCD phải gồm đúng 12 chữ số';
  }
  return null;
}

String? validateIdentityIssuedDate(DateTime? value, {DateTime? today}) {
  if (value == null) return 'Vui lòng chọn ngày cấp';
  final now = today ?? DateTime.now();
  final dateOnly = DateTime(value.year, value.month, value.day);
  final todayOnly = DateTime(now.year, now.month, now.day);
  if (dateOnly.isAfter(todayOnly)) {
    return 'Ngày cấp không được ở tương lai';
  }
  return null;
}

String? validateIdentityIssuedPlace(String? value) {
  final place = value?.trim() ?? '';
  if (place.isEmpty) return 'Vui lòng nhập nơi cấp';
  if (place.length > 255) {
    return 'Nơi cấp không được vượt quá 255 ký tự';
  }
  return null;
}

String? validatePermanentAddress(String? value) {
  final address = value?.trim() ?? '';
  if (address.isEmpty) return 'Vui lòng nhập địa chỉ thường trú';
  if (address.length > 1000) {
    return 'Địa chỉ thường trú không được vượt quá 1000 ký tự';
  }
  return null;
}

String? validateProfileEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Vui lòng nhập email';
  if (email.length > 255) return 'Email không được vượt quá 255 ký tự';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Địa chỉ email không đúng định dạng';
  }
  return null;
}

String formatIdentityIssuedDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
