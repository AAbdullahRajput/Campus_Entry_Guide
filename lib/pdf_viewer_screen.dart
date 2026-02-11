import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PDFViewerScreen extends StatefulWidget {
  final String pdfBase64;
  final String filename;
  final String? shift;
  final String? semester;
  final String? version;

  const PDFViewerScreen({
    Key? key,
    required this.pdfBase64,
    required this.filename,
    this.shift,
    this.semester,
    this.version,
  }) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  int _currentPage = 0;
  int _totalPages = 0;
  double _zoomLevel = 1.0;
  bool _isLoading = true;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    _saveTempFile();
  }

  Future<void> _saveTempFile() async {
    try {
      final bytes = base64Decode(widget.pdfBase64);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_timetable.pdf');
      await file.writeAsBytes(bytes);
      setState(() {
        _tempFilePath = file.path;
        _isLoading = false;
      });
      print('✅ PDF saved to temp file: $_tempFilePath');
    } catch (e) {
      print('❌ Error saving PDF: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF() async {
    if (_tempFilePath == null) return;

    try {
      await Share.shareXFiles(
        [XFile(_tempFilePath!)],
        text: 'My Timetable - ${widget.semester ?? ""}',
      );
    } catch (e) {
      print('❌ Error sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadPDF() async {
    try {
      final bytes = base64Decode(widget.pdfBase64);
      final dir = await getExternalStorageDirectory();
      final fileName = 'Timetable_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir?.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PDF saved to: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error downloading PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _zoomIn() {
    if (_zoomLevel < 3.0) {
      setState(() => _zoomLevel += 0.25);
      _pdfViewerController.zoomLevel = _zoomLevel;
    }
  }

  void _zoomOut() {
    if (_zoomLevel > 0.5) {
      setState(() => _zoomLevel -= 0.25);
      _pdfViewerController.zoomLevel = _zoomLevel;
    }
  }

  void _resetZoom() {
    setState(() => _zoomLevel = 1.0);
    _pdfViewerController.zoomLevel = 1.0;
  }

  @override
  void dispose() {
    // Clean up temp file
    if (_tempFilePath != null) {
      try {
        File(_tempFilePath!).deleteSync();
      } catch (e) {
        print('⚠️ Failed to delete temp file: $e');
      }
    }
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.filename,
              style: const TextStyle(fontSize: 16),
            ),
            if (widget.semester != null || widget.shift != null)
              Text(
                '${widget.shift ?? ""} ${widget.semester ?? ""}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        backgroundColor: Colors.deepPurple,foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePDF,
            tooltip: 'Share PDF',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadPDF,
            tooltip: 'Download PDF',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 10),
                    Text('PDF Info'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'info') {
                _showPDFInfo();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Loading PDF...'),
                ],
              ),
            )
          : _tempFilePath == null
              ? const Center(child: Text('Error loading PDF'))
              : Column(
                  children: [
                    // PDF Info Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.deepPurple.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page ${_currentPage + 1} of $_totalPages',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Zoom: ${(_zoomLevel * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // PDF Viewer
                    Expanded(
                      child: SfPdfViewer.file(
                        File(_tempFilePath!),
                        controller: _pdfViewerController,
                        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                          setState(() {
                            _totalPages = details.document.pages.count;
                          });
                          print('✅ PDF loaded: $_totalPages pages');
                        },
                        onPageChanged: (PdfPageChangedDetails details) {
                          setState(() {
                            _currentPage = details.newPageNumber - 1;
                          });
                        },
                      ),
                    ),

                    // Control Bar
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 5,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Previous Page
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 0
                                ? () {
                                    _pdfViewerController.previousPage();
                                  }
                                : null,
                            tooltip: 'Previous Page',
                          ),

                          // Zoom Out
                          IconButton(
                            icon: const Icon(Icons.zoom_out),
                            onPressed: _zoomLevel > 0.5 ? _zoomOut : null,
                            tooltip: 'Zoom Out',
                          ),

                          // Reset Zoom
                          TextButton(
                            onPressed: _resetZoom,
                            child: Text(
                              '${(_zoomLevel * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),

                          // Zoom In
                          IconButton(
                            icon: const Icon(Icons.zoom_in),
                            onPressed: _zoomLevel < 3.0 ? _zoomIn : null,
                            tooltip: 'Zoom In',
                          ),

                          // Next Page
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < _totalPages - 1
                                ? () {
                                    _pdfViewerController.nextPage();
                                  }
                                : null,
                            tooltip: 'Next Page',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showPDFInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📄 PDF Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Filename', widget.filename),
            if (widget.shift != null) _infoRow('Shift', widget.shift!),
            if (widget.semester != null) _infoRow('Semester', widget.semester!),
            if (widget.version != null) _infoRow('Version', widget.version!),
            _infoRow('Total Pages', '$_totalPages'),
            _infoRow('Current Page', '${_currentPage + 1}'),
            _infoRow('Zoom Level', '${(_zoomLevel * 100).toInt()}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}