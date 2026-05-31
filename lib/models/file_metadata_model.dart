
enum FileCategory {
  ID_CARD,
  CONTRACT,
  INVOICE,
  MAINTENANCE,
  OTHER;

  String toJson() => name;
}

class FileMetadataResponse {
  const FileMetadataResponse({
    required this.fileId,
    required this.originalFileName,
    required this.url,
    required this.uploaded,
    this.message,
  });

  final int fileId;
  final String originalFileName;
  final String url;
  final bool uploaded;
  final String? message;

  factory FileMetadataResponse.fromJson(Map<String, dynamic> json) {
    return FileMetadataResponse(
      fileId: (json['fileId'] as num?)?.toInt() ?? 0,
      originalFileName: json['originalFileName']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      uploaded: json['uploaded'] as bool? ?? false,
      message: json['message']?.toString(),
    );
  }
}

class BatchFileResponse {
  const BatchFileResponse({
    required this.totalFiles,
    required this.successfulUploads,
    required this.failedUploads,
    required this.fileMetadataResponse,
    this.message,
  });

  final int totalFiles;
  final int successfulUploads;
  final int failedUploads;
  final List<FileMetadataResponse> fileMetadataResponse;
  final String? message;

  factory BatchFileResponse.fromJson(Map<String, dynamic> json) {
    return BatchFileResponse(
      totalFiles: (json['totalFiles'] as num?)?.toInt() ?? 0,
      successfulUploads: (json['successfulUploads'] as num?)?.toInt() ?? 0,
      failedUploads: (json['failedUploads'] as num?)?.toInt() ?? 0,
      fileMetadataResponse: (json['fileMetadataResponse'] as List<dynamic>?)
              ?.map((e) => FileMetadataResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      message: json['message']?.toString(),
    );
  }
}
