import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_application/core/theme/app_theme.dart'; // for accent color

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
      throw Exception('Download failed (HTTP ${res.statusCode}).');
    }
    throw Exception('No PDF source available.');
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
        final pathStr = savedPath.toString();
        showPdfSavedSnack(
          context,
          fileName: name,
          openPath: pathStr.isNotEmpty ? pathStr : null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showPdfErrorSnack(context, message: 'Save error: $e');
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
      // (Niente snack di successo qui: la condivisione apre il foglio di sistema)
    } catch (e) {
      if (context.mounted) {
        showPdfErrorSnack(context, message: 'Share error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ---------- Responsive metrics ----------
    final w = MediaQuery.of(context).size.width;
    final double titleFont = (w * 0.055).clamp(18.0, 22.0);
    final double iconSize = (w * 0.075).clamp(22.0, 28.0);

    final Widget viewer = (pdfFile != null && File(pdfFile!).existsSync())
        ? SfPdfViewer.file(
            File(pdfFile!),
            initialPageNumber: (initialPage ?? 1),
          )
        : (pdfUrl != null && pdfUrl!.isNotEmpty)
        ? SfPdfViewer.network(pdfUrl!, initialPageNumber: (initialPage ?? 1))
        : const Center(child: Text('No PDF to display'));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: titleFont),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actionsIconTheme: IconThemeData(size: iconSize),
        iconTheme: IconThemeData(size: iconSize, color: Colors.black87),
        actions: [
          // Download
          IconButton(
            tooltip: 'Download PDF',
            icon: Icon(Icons.download, size: iconSize),
            onPressed: () => _downloadPdf(context),
          ),
          // Share
          IconButton(
            tooltip: 'Share PDF',
            icon: Icon(Icons.share, size: iconSize),
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: viewer,
    );
  }
}

/// Fancy success snack (matches the style of "added to cart")
void showPdfSavedSnack(
  BuildContext context, {
  required String fileName,
  String? openPath,
}) {
  final w = MediaQuery.of(context).size.width;

  final double badge = (w * 0.085).clamp(26.0, 34.0);
  final double check = (badge * 0.6).clamp(16.0, 20.0);
  final double titleFont = (w * 0.04).clamp(13.0, 15.0);
  final double subFont = (w * 0.035).clamp(11.0, 13.0);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      duration: const Duration(seconds: 2),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Row(
          children: [
            Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.check, size: check, color: Colors.white),
            ),
            const SizedBox(width: 12),
            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PDF saved',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: titleFont,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: subFont,
                      color: Colors.black54,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (openPath != null)
              TextButton(
                onPressed: () => OpenFilex.open(openPath),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'OPEN',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Error snack with same visual language
void showPdfErrorSnack(BuildContext context, {required String message}) {
  final w = MediaQuery.of(context).size.width;

  final double badge = (w * 0.085).clamp(26.0, 34.0);
  final double icon = (badge * 0.6).clamp(16.0, 20.0);
  final double titleFont = (w * 0.04).clamp(13.0, 15.0);
  final double subFont = (w * 0.035).clamp(11.0, 13.0);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      duration: const Duration(seconds: 3),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Row(
          children: [
            Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.error_outline, size: icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Something went wrong',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: titleFont,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: subFont,
                      color: Colors.black54,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
