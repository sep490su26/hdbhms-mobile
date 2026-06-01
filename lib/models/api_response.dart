class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.message,
    this.details,
    this.data,
  });

  final int code;
  final String? message;
  final String? details;
  final T? data;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int? ?? 0,
      message: json['message']?.toString(),
      details: json['details']?.toString(),
      data: json['data'] != null ? fromJsonT(json['data']) : null,
    );
  }

  bool get isSuccess => code >= 200 && code < 300 || code == 0;
}
