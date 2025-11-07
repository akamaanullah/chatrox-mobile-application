import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String? title;
  const PdfViewerScreen({Key? key, required this.url, this.title}) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'PDF'),
        backgroundColor: Colors.teal,
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            widget.url,
            onDocumentLoaded: (details) {
              print('DEBUG: PDF loaded successfully: ' + widget.url);
              setState(() {
                _isLoading = false;
                _error = null;
              });
            },
            onDocumentLoadFailed: (details) {
              print('DEBUG: PDF load failed: ' + details.description);
              setState(() {
                _isLoading = false;
                _error = details.description;
              });
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load PDF',
                      style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(fontSize: 15, color: Colors.black54)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 