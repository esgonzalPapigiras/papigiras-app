import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../lab/media.dart';
import '../utils/medical_pdf_name.dart';
import '../lab/session.dart';
import 'pilo_family_theme.dart';

/// Displays the existing authorized medical PDF, never an editable form.
Future<void> showPiloStudentMedicalSheet(
  BuildContext context, {
  required String studentName,
  String studentIdentification = '',
  required Future<Uint8List> Function() loadPdf,
  @visibleForTesting Widget Function(BuildContext, String)? pdfBuilder,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: PiloFamilyTheme.paper,
  barrierColor: PiloFamilyTheme.ink.withValues(alpha: .34),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
  ),
  clipBehavior: Clip.antiAlias,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (context) => PiloStudentMedicalSheet(
    studentName: studentName,
    studentIdentification: studentIdentification,
    loadPdf: loadPdf,
    pdfBuilder: pdfBuilder,
  ),
);

class PiloStudentMedicalSheet extends StatefulWidget {
  const PiloStudentMedicalSheet({
    super.key,
    required this.studentName,
    this.studentIdentification = '',
    required this.loadPdf,
    this.pdfBuilder,
  });

  final String studentName;
  final String studentIdentification;
  final Future<Uint8List> Function() loadPdf;
  @visibleForTesting
  final Widget Function(BuildContext, String)? pdfBuilder;

  @override
  State<PiloStudentMedicalSheet> createState() =>
      _PiloStudentMedicalSheetState();
}

class _PiloStudentMedicalSheetState extends State<PiloStudentMedicalSheet> {
  String? _filePath;
  String? _exportPath;
  String? _actionMessage;
  bool _sharing = false;
  bool _loading = true;
  bool _failed = false;
  bool _revoked = false;
  int _request = 0;
  int _page = 0;
  int? _pages;
  late final int _generation;

  @override
  void initState() {
    super.initState();
    _generation = LabSession.generation;
    LabSession.changed.addListener(_sessionChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant PiloStudentMedicalSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadPdf != widget.loadPdf ||
        oldWidget.studentName != widget.studentName ||
        oldWidget.studentIdentification != widget.studentIdentification) {
      _load();
    }
  }

  bool _current(int request) =>
      mounted &&
      !_revoked &&
      request == _request &&
      _generation == LabSession.generation;

  static Future<void> _remove(String? path) async {
    if (path == null) return;
    try {
      await LabMedia.removePreview(path);
    } catch (_) {
      // No PDF contents, identity, temporary path or exception is logged.
    }
  }

  Future<void> _removeWhenIdle(String? path) async {
    // A native share sheet may still be reading the PDF after this sheet closes.
    // Its operation owns cleanup until the system picker returns.
    if (path != null && path != _exportPath) await _remove(path);
  }

  Future<void> _export(BuildContext context, {required bool share}) async {
    final path = _filePath;
    final request = _request;
    if (path == null || _exportPath != null || !_current(request)) return;
    setState(() {
      _exportPath = path;
      _sharing = share;
      _actionMessage = null;
    });
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      if (!_current(request) || _filePath != path || !context.mounted) return;
      if (share) {
        await LabMedia.sharePdf(
          file,
          context: context,
          name: MedicalPdfName.forPassenger(
            widget.studentName,
            widget.studentIdentification,
          ),
          text: 'Ficha médica',
          isCurrent: () =>
              _current(request) && _filePath == path && context.mounted,
        );
      } else {
        final saved = await LabMedia.exportPdf(
          bytes,
          MedicalPdfName.forPassenger(
            widget.studentName,
            widget.studentIdentification,
          ),
          dialogTitle: 'Guardar ficha médica',
        );
        if (_current(request) && _filePath == path && saved != null) {
          setState(() => _actionMessage = 'Ficha médica guardada.');
        }
      }
    } catch (_) {
      if (_current(request) && _filePath == path) {
        setState(() {
          _actionMessage = share
              ? 'No pudimos compartir la ficha. Inténtalo nuevamente.'
              : 'No pudimos guardar la ficha. Inténtalo nuevamente.';
        });
      }
    } finally {
      _exportPath = null;
      if (!mounted || _revoked || _filePath != path) await _remove(path);
      if (mounted) setState(() {});
    }
  }

  void _sessionChanged() {
    ++_request;
    final previous = _filePath;
    if (mounted) {
      setState(() {
        _filePath = null;
        _revoked = true;
        _loading = false;
        _pages = null;
        _actionMessage = null;
      });
    }
    unawaited(_removeWhenIdle(previous));
  }

  Future<void> _load() async {
    if (_revoked || _generation != LabSession.generation) return;
    final request = ++_request;
    final previous = _filePath;
    setState(() {
      _filePath = null;
      _failed = false;
      _loading = true;
      _page = 0;
      _pages = null;
      _actionMessage = null;
    });
    await _removeWhenIdle(previous);
    if (!_current(request)) return;
    try {
      final bytes = await widget.loadPdf();
      if (!_current(request)) return;
      // LabMedia validates the PDF and writes only to its private preview dir.
      final file = await LabMedia.storePdf(bytes, 'ficha-medica.pdf');
      if (!_current(request)) {
        await _remove(file.path);
        return;
      }
      setState(() {
        _filePath = file.path;
        _loading = false;
      });
    } catch (_) {
      if (!_current(request)) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _renderFailed(String path) {
    if (!mounted || _filePath != path || _revoked) return;
    setState(() {
      _filePath = null;
      _failed = true;
      _pages = null;
    });
    unawaited(_removeWhenIdle(path));
  }

  @override
  void dispose() {
    ++_request;
    LabSession.changed.removeListener(_sessionChanged);
    unawaited(_removeWhenIdle(_filePath));
    super.dispose();
  }

  Widget _document(BuildContext context, String path) =>
      widget.pdfBuilder?.call(context, path) ??
      Stack(
        children: [
          PDFView(
            key: ValueKey(path),
            filePath: path,
            preventLinkNavigation: true,
            onLinkHandler: (_) {},
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: false,
            onRender: (pages) {
              if (mounted && _filePath == path && !_revoked) {
                setState(() => _pages = pages);
              }
            },
            onPageChanged: (page, total) {
              if (mounted && _filePath == path && !_revoked) {
                setState(() {
                  _page = page ?? 0;
                  _pages = total;
                });
              }
            },
            onError: (_) => _renderFailed(path),
            onPageError: (_, _) => _renderFailed(path),
          ),
          if (_pages == null) const Center(child: CircularProgressIndicator()),
        ],
      );

  Widget _message(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Abriendo tu ficha médica…',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Icon(
              _revoked
                  ? Icons.lock_outline_rounded
                  : Icons.description_outlined,
              size: 34,
              color: PiloFamilyTheme.secondary,
            ),
            const SizedBox(height: 14),
            Text(
              _revoked
                  ? 'La sesión cambió. Cierra esta ficha para continuar.'
                  : 'No pudimos abrir tu ficha médica.',
              textAlign: TextAlign.center,
            ),
            if (_failed && !_revoked) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('student-medical-retry'),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ],
      ),
    ),
  );

  Widget _actions(BuildContext context) {
    final busy = _exportPath != null;
    Widget action({required bool share}) => FilledButton.icon(
      key: ValueKey(
        share ? 'student-medical-share' : 'student-medical-download',
      ),
      onPressed: busy ? null : () => _export(context, share: share),
      style: FilledButton.styleFrom(
        backgroundColor: share ? PiloFamilyTheme.mint : PiloFamilyTheme.soft,
        foregroundColor: PiloFamilyTheme.ink,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
      ),
      icon: busy && _sharing == share
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              share ? Icons.ios_share_rounded : Icons.download_rounded,
              size: 20,
            ),
      label: Text(share ? 'Compartir' : 'Descargar'),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_actionMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _actionMessage!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (MediaQuery.textScalerOf(context).scale(14) > 21)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                action(share: true),
                const SizedBox(height: 8),
                action(share: false),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: action(share: true)),
                const SizedBox(width: 10),
                Expanded(child: action(share: false)),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Builder(
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .92,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: PiloFamilyTheme.connectorLine,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Ficha médica',
                          style: PiloFamilyTheme.display(
                            MediaQuery.textScalerOf(context).scale(14) > 21
                                ? 22
                                : 31,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey('student-medical-close'),
                      tooltip: 'Cerrar ficha médica',
                      style: IconButton.styleFrom(
                        backgroundColor: PiloFamilyTheme.soft,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _revoked ? 'Sesión finalizada' : widget.studentName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: PiloFamilyTheme.soft,
                  child: _filePath != null && !_revoked
                      ? _document(context, _filePath!)
                      : _message(context),
                ),
              ),
              if (_pages != null && !_revoked)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '${_page + 1} / $_pages',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_filePath != null && !_revoked) _actions(context),
            ],
          ),
        ),
      ),
    ),
  );
}
