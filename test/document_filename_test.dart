import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/utils/document_filename.dart';

void main() {
  test('buildDocumentFilename formats type room date', () {
    expect(
      buildDocumentFilename(
        documentType: 'HDT',
        roomCode: '205',
        date: DateTime(2026, 7, 16),
      ),
      'HDT_P205_16_07_2026.pdf',
    );
    expect(
      buildDocumentFilename(documentType: 'HDC', roomCode: 'P201'),
      'HDC_P201_Chua-Ro-Ngay.pdf',
    );
  });

  test('resolvePdfDownloadFilename prefers suggested filename', () {
    expect(
      resolvePdfDownloadFilename(
        contentDisposition:
            "attachment; filename*=UTF-8''BBBG_P205_16_07_2026.pdf",
        suggestedFilename: 'HDT_P201_16_07_2026.pdf',
      ),
      'HDT_P201_16_07_2026.pdf',
    );
  });

  test('resolvePdfDownloadFilename falls back to content disposition', () {
    expect(
      resolvePdfDownloadFilename(
        contentDisposition:
            "attachment; filename*=UTF-8''BBBG_P205_16_07_2026.pdf",
      ),
      'BBBG_P205_16_07_2026.pdf',
    );
  });
}
