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
      tenantProfileId: _asInt(json['tenant_profile_id'] ?? json['id']),
      status: json['status']?.toString() ?? '',
      person: PersonProfileDto.fromJson(
        json['person'] as Map<String, dynamic>? ??
            json['person_profile'] as Map<String, dynamic>? ??
            {},
      ),
      identityDocument:
          (json['identity_document'] ?? json['identityDocument'])
              is Map<String, dynamic>
          ? IdentityDocumentDto.fromJson(
              (json['identity_document'] ?? json['identityDocument'])
                  as Map<String, dynamic>,
            )
          : null,
      vehicles: _asList(json['vehicles'])
          .whereType<Map<String, dynamic>>()
          .map(VehicleDto.fromJson)
          .toList(growable: false),
      emergencyContacts:
          _asList(json['emergency_contacts'] ?? json['emergencyContacts'])
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
      fullName: _firstString(json, ['full_name', 'fullName']),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      permanentAddress: _firstString(json, ['permanent_address', 'permanentAddress']),
      portraitFileUrl: _firstString(json, [
        'portrait_file_url',
        'portraitFileUrl',
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
      docType: _firstString(json, ['doc_type', 'docType']),
      docNumber: _visibleDocNumber(_firstString(json, ['doc_number', 'docNumber'])),
      issuedDate: DateTime.tryParse(_firstString(json, ['issued_date', 'issuedDate'])),
      issuedPlace: _firstString(json, ['issued_place', 'issuedPlace']),
      frontFileUrl: _firstString(json, [
        'front_file_url',
        'frontFileUrl',
        'id_card_front_url',
      ]),
      backFileUrl: _firstString(json, [
        'back_file_url',
        'backFileUrl',
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
      vehicleType: _firstString(json, ['vehicle_type', 'vehicleType']),
      licensePlate: _firstString(json, ['license_plate', 'licensePlate']),
      imageUrl: _firstString(json, [
        'image_url',
        'imageUrl',
        'signed_url',
        'signedUrl',
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
      fullName: _firstString(json, ['full_name', 'fullName']),
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
