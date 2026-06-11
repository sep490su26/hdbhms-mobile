class UserResponse {
  const UserResponse({
    required this.id,
    required this.phone,
    required this.email,
    required this.role,
    required this.mustChangePassword,
    required this.status,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int id;
  final String phone;
  final String email;
  final String role;
  final bool mustChangePassword;
  final String status;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      mustChangePassword: json['mustChangePassword'] == true,
      status: json['status']?.toString() ?? '',
      lastLoginAt: DateTime.tryParse(json['lastLoginAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      deletedAt: DateTime.tryParse(json['deletedAt']?.toString() ?? ''),
    );
  }
}
