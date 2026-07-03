import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/api_response.dart';
import 'package:hdbhms_mobile/models/maintenance/file_metadata_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';

class FileService {
  const FileService({http.Client? client}) : _client = client;

  final http.Client? _client;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();

  Future<FileMetadataResponse> uploadSingle({
    required Uint8List bytes,
    required String fileName,
    FileCategory category = FileCategory.other,
    bool isSensitive = false,
  }) async {
    final client = _effectiveClient;
    final uri = Uri.parse('${ApiConfig.baseUrl}/files/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['category'] = category.name
      ..fields['isSensitive'] = isSensitive.toString()
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: _getContextType(fileName),
        ),
      );

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final apiResponse = ApiResponse<FileMetadataResponse>.fromJson(
        data,
        (json) => FileMetadataResponse.fromJson(json as Map<String, dynamic>),
      );
      return apiResponse.data!;
    } else {
      throw Exception('Failed to upload file: ${response.body}');
    }
  }

  Future<BatchFileResponse> uploadBatch({
    required List<({Uint8List bytes, String fileName})> files,
    required FileCategory category,
    bool isSensitive = false,
  }) async {
    final client = _effectiveClient;
    final uri = Uri.parse('${ApiConfig.baseUrl}/files/upload/batch');

    final request = http.MultipartRequest('POST', uri)
      ..fields['category'] = category.name
      ..fields['isSensitive'] = isSensitive.toString();

    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          file.bytes,
          filename: file.fileName,
          contentType: _getContextType(file.fileName),
        ),
      );
    }

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final apiResponse = ApiResponse<BatchFileResponse>.fromJson(
        data,
        (json) => BatchFileResponse.fromJson(json as Map<String, dynamic>),
      );
      return apiResponse.data!;
    } else {
      throw Exception('Failed to upload batch files: ${response.body}');
    }
  }

  Future<Uint8List> download(int fileId) async {
    final client = _effectiveClient;

    try {
      final response = await client.get(
        Uri.parse('${ApiConfig.baseUrl}/files/download/$fileId'),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file: ${response.body}');
      }
    } finally {
      if (_client == null) client.close();
    }
  }

  MediaType _getContextType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
