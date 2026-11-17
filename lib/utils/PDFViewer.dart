import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';

class PDFViewer extends StatefulWidget {
  const PDFViewer({super.key, required this.filePath});

  final String filePath;

  @override
  State<PDFViewer> createState() => _PDFViewerState();
}

class _PDFViewerState extends State<PDFViewer> {
  int _page = 0;
  int? _pages;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documento')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: PapigirasColors.soft,
            child: _error == null
                ? Stack(
                    children: [
                      PDFView(
                        filePath: widget.filePath,
                        enableSwipe: true,
                        swipeHorizontal: false,
                        autoSpacing: false,
                        pageFling: false,
                        onRender: (pages) {
                          if (mounted) setState(() => _pages = pages);
                        },
                        onPageChanged: (page, total) {
                          if (!mounted) return;
                          setState(() {
                            _page = page ?? 0;
                            _pages = total;
                          });
                        },
                        onError: (error) {
                          if (mounted) {
                            setState(() => _error = error.toString());
                          }
                        },
                        onPageError: (_, error) {
                          if (mounted) {
                            setState(() => _error = error.toString());
                          }
                        },
                      ),
                      if (_pages == null)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 52,
                            color: PapigirasColors.teal,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No se pudo abrir el documento',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _pages == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${_page + 1} / $_pages',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
    );
  }
}
