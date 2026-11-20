import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/session.dart';

class PDFViewer extends StatefulWidget {
  final String filePath;
  final String? documentName;
  final bool isMedicalRecord;
  const PDFViewer({
    super.key,
    required this.filePath,
    this.documentName,
    this.isMedicalRecord = false,
  });

  @override
  State<PDFViewer> createState() => _PDFViewerState();
}

class _PDFViewerState extends State<PDFViewer> {
  int _page = 0;
  int? _pages;
  String? _error;

  @override
  void dispose() {
    unawaited(
      LabMedia.removePreview(widget.filePath).catchError((Object _) {}),
    );
    super.dispose();
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo completar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Visualizando PDF'),
      actions: [
        IconButton(
          tooltip: 'Guardar PDF',
          icon: const Icon(Icons.download),
          onPressed: () => _action(() async {
            final generation = LabSession.generation;
            final file = File(widget.filePath);
            await LabMedia.exportPdf(
              await file.readAsBytes(),
              widget.documentName ?? file.path.split('/').last,
              dialogTitle: widget.isMedicalRecord
                  ? 'Guardar ficha médica'
                  : 'Guardar PDF',
              isCurrent: () => mounted && generation == LabSession.generation,
            );
          }),
        ),
        IconButton(
          tooltip: 'Compartir PDF',
          icon: const Icon(Icons.share),
          onPressed: () => _action(() async {
            final generation = LabSession.generation;
            await LabMedia.sharePdf(
              File(widget.filePath),
              context: context,
              name: widget.documentName,
              isCurrent: () => mounted && generation == LabSession.generation,
              text: widget.isMedicalRecord
                  ? 'Ficha médica'
                  : 'Documento de PapiGiras',
            );
          }),
        ),
      ],
    ),
    body: _error != null
        ? Center(child: Text('No se pudo abrir el PDF: $_error'))
        : Stack(
            children: [
              PDFView(
                filePath: widget.filePath,
                preventLinkNavigation: true,
                onLinkHandler: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Los enlaces externos de este PDF están desactivados.',
                      ),
                    ),
                  );
                },
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: false,
                pageFling: false,
                onRender: (pages) {
                  if (mounted) setState(() => _pages = pages);
                },
                onPageChanged: (page, total) {
                  if (mounted)
                    setState(() {
                      _page = page ?? 0;
                      _pages = total;
                    });
                },
                onError: (error) {
                  if (mounted) setState(() => _error = error.toString());
                },
                onPageError: (page, error) {
                  if (mounted) setState(() => _error = error.toString());
                },
              ),
              if (_pages == null)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
    bottomNavigationBar: _pages == null
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${_page + 1} / $_pages',
                textAlign: TextAlign.center,
              ),
            ),
          ),
  );
}
