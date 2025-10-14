import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';

class PdfViewerPage extends StatelessWidget {
  final String title;
  final String? pdfFile;
  final String? pdfUrl;
  final int? initialPage;

  const PdfViewerPage({
    super.key,
    required this.title,
    this.pdfFile,
    this.pdfUrl,
    this.initialPage,
  });

  Future<Uint8List> _loadPdfBytes() async {
    if (pdfFile != null && File(pdfFile!).existsSync()) {
      return File(pdfFile!).readAsBytes();
    }
    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      final res = await http.get(Uri.parse(pdfUrl!));
      if (res.statusCode == 200) return res.bodyBytes;
      throw Exception('Download fallito (HTTP ${res.statusCode}).');
    }
    throw Exception('Nessuna sorgente PDF disponibile.');
  }

  String _suggestedFileName() {
    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      final uri = Uri.parse(pdfUrl!);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      if (last != null && last.toLowerCase().endsWith('.pdf')) return last;
    }
    final safe = title.trim().isEmpty ? 'document' : title.trim();
    return '${safe.replaceAll(RegExp(r"[^\w\s\-]"), "").replaceAll(" ", "_")}.pdf';
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final bytes = await _loadPdfBytes();
      final name = _suggestedFileName();

      final savedPath = await FileSaver.instance.saveFile(
        name: name,
        fileExtension: 'pdf',
        bytes: bytes,
        mimeType: MimeType.pdf,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF salvato: $name'),
            action: (savedPath.toString().isNotEmpty)
                ? SnackBarAction(
                    label: 'APRI',
                    onPressed: () => OpenFilex.open(savedPath.toString()),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e')));
      }
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      XFile xfile;
      if (pdfFile != null && File(pdfFile!).existsSync()) {
        xfile = XFile(
          pdfFile!,
          mimeType: 'application/pdf',
          name: _suggestedFileName(),
        );
      } else {
        final bytes = await _loadPdfBytes();
        final tempDir = await getTemporaryDirectory();
        final tmpPath = '${tempDir.path}/${_suggestedFileName()}';
        final f = File(tmpPath);
        await f.writeAsBytes(bytes, flush: true);
        xfile = XFile(
          f.path,
          mimeType: 'application/pdf',
          name: _suggestedFileName(),
        );
      }

      await Share.shareXFiles([xfile], text: title);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore condivisione: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget viewer = (pdfFile != null && File(pdfFile!).existsSync())
        ? SfPdfViewer.file(
            File(pdfFile!),
            initialPageNumber: (initialPage ?? 1),
          )
        : (pdfUrl != null && pdfUrl!.isNotEmpty)
        ? SfPdfViewer.network(pdfUrl!, initialPageNumber: (initialPage ?? 1))
        : const Center(child: Text('Nessun PDF da mostrare'));
        
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          // Scarica
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.download),
            onPressed: () => _downloadPdf(context),
          ),
          // Condividi
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.share),
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: viewer,
    );
  }
}
