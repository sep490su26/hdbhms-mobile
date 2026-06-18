import 'package:flutter/material.dart';

Widget buildPlatformPdfViewer({
  required BuildContext context,
  required String pdfUrl,
  required String title,
}) {
  throw UnsupportedError('Cannot create a PDF viewer without dart:html or dart:io');
}
