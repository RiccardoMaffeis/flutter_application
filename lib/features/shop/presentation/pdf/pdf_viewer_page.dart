import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerPage extends StatelessWidget {
  final String title;
  final String? pdfFile;
  final String? pdfUrl;

  const PdfViewerPage({
    super.key,
    required this.title,
    this.pdfFile,
    this.pdfUrl,
  });

  @override
  Widget build(BuildContext context) {
    final Widget viewer =
        (pdfFile != null && File(pdfFile!).existsSync())
            ? SfPdfViewer.file(File(pdfFile!))
            : (pdfUrl != null && pdfUrl!.isNotEmpty)
                ? SfPdfViewer.network(pdfUrl!)
                : const Center(child: Text('Nessun PDF da mostrare'));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: viewer,
    );
  }
}
