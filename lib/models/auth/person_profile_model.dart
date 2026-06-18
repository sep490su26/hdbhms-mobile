import 'package:hdbhms_mobile/models/maintenance/file_metadata_model.dart';

class PersonProfileResponse {
  const PersonProfileResponse({
    required this.id,
    required this.userId,
    required this.fullName,
    this.dob,
    this.gender,
    required this.phone,
    required this.email,
    required this.permanentAddress,
    this.portraitFile,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int id;
  final int userId;
  final String fullName;
  final DateTime? dob;
  final String? gender;
  final String phone;
  final String email;
  final String permanentAddress;
  final FileMetadataResponse? portraitFile;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  factory PersonProfileResponse.fromJson(Map<String, dynamic> json) {
    return PersonProfileResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      dob: DateTime.tryParse(json['dob']?.toString() ?? ''),
      gender: json['gender']?.toString(),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      permanentAddress: json['permanentAddress']?.toString() ?? '',
      portraitFile: json['portraitFile'] != null
          ? FileMetadataResponse.fromJson(json['portraitFile'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      deletedAt: DateTime.tryParse(json['deletedAt']?.toString() ?? ''),
    );
  }
}
