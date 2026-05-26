class FileMetadataResponse {
  const FileMetadataResponse({
    required this.id,
    required this.fileName,
    required this.fileKey,
    required this.fileUrl,
    required this.fileType,
    required this.size,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String fileName;
  final String fileKey;
  final String fileUrl;
  final String fileType;
  final int size;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FileMetadataResponse.fromJson(Map<String, dynamic> json) {
    return FileMetadataResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fileName: json['fileName']?.toString() ?? '',
      fileKey: json['fileKey']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? '',
      fileType: json['fileType']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
