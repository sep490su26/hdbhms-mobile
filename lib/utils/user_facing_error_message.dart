/// Filters technical transport/state strings before they are shown to a tenant.
/// The original value remains available to callers for diagnostics and logging.
String toUserFacingMessage(
  String? raw, {
  String fallback = 'Không thể thực hiện thao tác. Vui lòng thử lại.',
}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return fallback;

  final normalized = value.toLowerCase();
  const technicalValues = {
    'invalid',
    'invalid_request',
    'invalid_request_state',
    'invalid request',
    'room transfer invalid state',
  };
  if (technicalValues.contains(normalized) ||
      normalized.startsWith('invalid request') ||
      normalized.contains('invalid state')) {
    return 'Yêu cầu không hợp lệ. Vui lòng kiểm tra thông tin và thử lại.';
  }
  return value;
}
