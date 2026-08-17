import 'package:flutter/material.dart';

import 'contract_pdf_viewer_stub.dart'
    if (dart.library.io) 'contract_pdf_viewer_mobile.dart'
    if (dart.library.html) 'contract_pdf_viewer_web.dart';

/// Full-screen PDF viewer used by both lease-contract and deposit-contract
/// detail screens.
///
/// Accepts a remote [pdfUrl] (the `contractFileUrl` from the API) and a
/// display [title] shown in the app bar.
class ContractPdfViewerScreen extends StatelessWidget {
  const ContractPdfViewerScreen({
    super.key,
    required this.pdfUrl,
    this.suggestedFilename,
    this.title = 'Tài liệu hợp đồng',
  });

  final String pdfUrl;
  final String title;
  final String? suggestedFilename;

  @override
  Widget build(BuildContext context) {
    final displayTitle = suggestedFilename?.trim().isNotEmpty == true
        ? suggestedFilename!.replaceAll(
            RegExp(r'\.pdf$', caseSensitive: false),
            '',
          )
        : title;

    return buildPlatformPdfViewer(
      context: context,
      pdfUrl: pdfUrl,
      title: displayTitle,
      suggestedFilename: suggestedFilename,
    );
  }
}
