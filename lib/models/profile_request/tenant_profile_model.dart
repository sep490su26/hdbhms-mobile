class TenantProfileResponse {
  const TenantProfileResponse({
    required this.tenantProfileId,
    required this.status,
    required this.person,
    required this.identityDocument,
    required this.vehicles,
    required this.emergencyContacts,
  });

  final int? tenantProfileId;
  final String status;
  final PersonProfileDto person;
  final IdentityDocumentDto? identityDocument;
  final List<VehicleDto> vehicles;
  final List<EmergencyContactDto> emergencyContacts;

  factory TenantProfileResponse.fromJson(Map<String, dynamic> json) {
    return TenantProfileResponse(
      tenantProfileId: _asInt(
        json['tenantProfileId'] ?? json['tenant_profile_id'] ?? json['id'],
      ),
      status: json['status']?.toString() ?? '',
      person: PersonProfileDto.fromJson(
        json['person'] as Map<String, dynamic>? ??
            json['personProfile'] as Map<String, dynamic>? ??
            json['person_profile'] as Map<String, dynamic>? ??
            {},
      ),
      identityDocument:
          (json['identityDocument'] ?? json['identity_document'])
              is Map<String, dynamic>
          ? IdentityDocumentDto.fromJson(
              (json['identityDocument'] ?? json['identity_document'])
                  as Map<String, dynamic>,
            )
          : null,
      vehicles: _asList(json['vehicles'])
          .whereType<Map<String, dynamic>>()
          .map(VehicleDto.fromJson)
          .toList(growable: false),
      emergencyContacts:
          _asList(json['emergencyContacts'] ?? json['emergency_contacts'])
              .whereType<Map<String, dynamic>>()
              .map(EmergencyContactDto.fromJson)
              .toList(growable: false),
    );
  }
}

class PersonProfileDto {
  const PersonProfileDto({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.permanentAddress,
    required this.portraitFileUrl,
  });

  final String fullName;
  final String phone;
  final String email;
  final String permanentAddress;
  final String portraitFileUrl;

  factory PersonProfileDto.fromJson(Map<String, dynamic> json) {
    return PersonProfileDto(
      fullName: _firstString(json, ['fullName', 'full_name']),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      permanentAddress: _firstString(json, [
        'permanentAddress',
        'permanent_address',
      ]),
      portraitFileUrl: _firstString(json, [
        'portraitFileUrl',
        'portrait_file_url',
      ]),
    );
  }
}

class IdentityDocumentDto {
  const IdentityDocumentDto({
    required this.docType,
    required this.docNumber,
    required this.issuedDate,
    required this.issuedPlace,
    required this.frontFileUrl,
    required this.backFileUrl,
  });

  final String docType;
  final String docNumber;
  final DateTime? issuedDate;
  final String issuedPlace;
  final String frontFileUrl;
  final String backFileUrl;

  factory IdentityDocumentDto.fromJson(Map<String, dynamic> json) {
    return IdentityDocumentDto(
      docType: _firstString(json, ['docType', 'doc_type']),
      docNumber: _visibleDocNumber(
        _firstString(json, ['docNumber', 'doc_number']),
      ),
      issuedDate: DateTime.tryParse(
        _firstString(json, ['issuedDate', 'issued_date']),
      ),
      issuedPlace: _firstString(json, ['issuedPlace', 'issued_place']),
      frontFileUrl: _firstString(json, [
        'frontFileUrl',
        'idCardFrontUrl',
        'front_file_url',
        'id_card_front_url',
      ]),
      backFileUrl: _firstString(json, [
        'backFileUrl',
        'idCardBackUrl',
        'back_file_url',
        'id_card_back_url',
      ]),
    );
  }
}

class VehicleDto {
  const VehicleDto({
    required this.id,
    required this.vehicleType,
    required this.licensePlate,
    required this.imageUrl,
  });

  final int? id;
  final String vehicleType;
  final String licensePlate;
  final String imageUrl;

  factory VehicleDto.fromJson(Map<String, dynamic> json) {
    return VehicleDto(
      id: _asInt(json['id']),
      vehicleType: _firstString(json, ['vehicleType', 'vehicle_type']),
      licensePlate: _firstString(json, ['licensePlate', 'license_plate']),
      imageUrl: _firstString(json, [
        'imageUrl',
        'signedUrl',
        'vehicleImageUrl',
        'image_url',
        'signed_url',
        'vehicle_image_url',
      ]),
    );
  }
}

class EmergencyContactDto {
  const EmergencyContactDto({
    required this.fullName,
    required this.relationship,
    required this.phone,
  });

  final String fullName;
  final String relationship;
  final String phone;

  factory EmergencyContactDto.fromJson(Map<String, dynamic> json) {
    return EmergencyContactDto(
      fullName: _firstString(json, ['fullName', 'full_name']),
      relationship: json['relationship']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

List<Object?> _asList(Object? value) {
  if (value is List) {
    return value;
  }
  return const [];
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return '';
}

String _visibleDocNumber(Object? value) {
  final docNumber = value?.toString().trim() ?? '';
  if (docNumber.toUpperCase().startsWith('PENDING-')) {
    return '';
  }
  return docNumber;
}
