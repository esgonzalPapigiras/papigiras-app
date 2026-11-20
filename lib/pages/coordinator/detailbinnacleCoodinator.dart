import 'package:papigiras_app/voice/trip_voice_player.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/maps/trip_hito_content.dart';
import 'package:papigiras_app/maps/trip_hito_edit_sheet.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/hito_location_source.dart';

class DetalleBitacoraCoordScreen extends StatefulWidget {
  const DetalleBitacoraCoordScreen({
    super.key,
    required this.idHito,
    required this.login,
    required this.canModify,
    this.provider,
    this.onSave,
    this.onHitoChanged,
    this.initialLocation,
  });
  final TourSales login;
  final String idHito;
  final bool canModify;
  final CoordinatorProviders? provider;
  final VoidCallback? onHitoChanged;
  final HitoLocationDraft? initialLocation;

  /// Optional test/host override; normal execution uses the approved provider update.
  final Future<void> Function(
    String title,
    String description,
    String closingNote,
  )?
  onSave;

  @override
  State<DetalleBitacoraCoordScreen> createState() =>
      _DetalleBitacoraCoordScreenState();
}

class _DetalleBitacoraCoordScreenState
    extends State<DetalleBitacoraCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final CoordinatorProviders _provider;
  late Future<DetailHitoList> _detail;
  bool _deleting = false;
  HitoLocationDraft? _savedLocation;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? CoordinatorProviders();
    _detail = _load();
  }

  Future<DetailHitoList> _load() {
    final request = _provider.getHitoComplete(
      widget.idHito,
      widget.login.tourSalesId.toString(),
    );
    // A retry may fail before the next frame attaches FutureBuilder. Register
    // an error listener now; the original future still exposes its error to UI.
    request.ignore();
    return request;
  }

  void _reload() {
    setState(() {
      _detail = _load();
    });
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  Future<void> _edit(DetailHitoList detail) async {
    if (!widget.canModify || _deleting) return;
    final save =
        widget.onSave ??
        (String title, String description, String closingNote) =>
            _provider.updateHito(
              idHito: widget.idHito,
              idTour: widget.login.tourSalesId.toString(),
              title: title,
              description: description,
              closingNote: closingNote,
            );
    final current = _savedLocation ?? widget.initialLocation;
    // Legacy records without a mappable point can be corrected explicitly.
    // This fallback is just the initial view, never sent unless it is selected.
    final initial =
        current ??
        HitoLocationDraft.selectedPoint(HitoLocationSource.initialMapCenter);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: PiloFamilyTheme.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => TripHitoEditSheet(
        detail: detail,
        onSave: save,
        initialLocation: initial,
        locationNeedsConfirmation: current == null,
        // Test/host text-only overrides keep their existing contract.
        onSaveWithLocation: widget.onSave != null
            ? null
            : (title, description, closingNote, location) async {
                await _provider.updateHito(
                  idHito: widget.idHito,
                  idTour: widget.login.tourSalesId.toString(),
                  title: title,
                  description: description,
                  closingNote: closingNote,
                  location: location,
                );
                if (mounted && location != null) _savedLocation = location;
              },
      ),
    );
    if (!mounted || saved != true) return;
    widget.onHitoChanged?.call();
    _reload();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
  }

  Future<void> _delete() async {
    if (!widget.canModify || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: PiloFamilyTheme.paper,
        surfaceTintColor: Colors.transparent,
        title: const Text('¿Eliminar este hito?'),
        content: const Text(
          'Se eliminarán el hito y sus fotografías. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _provider.deleteHito(
        widget.idHito,
        widget.login.tourSalesId.toString(),
      );
      if (!mounted) return;
      widget.onHitoChanged?.call();
      setState(() => _deleting = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos eliminar el hito. Vuelve a intentarlo.'),
          ),
        );
      }
    }
  }

  Widget _actions(DetailHitoList detail) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      OutlinedButton.icon(
        onPressed: _deleting ? null : () => _edit(detail),
        icon: const Icon(Icons.edit_outlined, size: 19),
        label: const Text('Editar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: PiloFamilyTheme.accentText,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: PiloFamilyTheme.hairline),
        ),
      ),
      TextButton.icon(
        onPressed: _deleting ? null : _delete,
        icon: _deleting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_outline, size: 20),
        label: Text(_deleting ? 'Eliminando hito…' : 'Eliminar hito'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFB3261E),
          minimumSize: const Size(0, 48),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: PopScope(
      canPop: !_deleting,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: PiloFamilyTheme.paper,
        endDrawer: _deleting ? null : CoordinatorEndDrawer(login: widget.login),
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: _deleting
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: PiloFamilyTheme.soft,
                      ),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Abrir menú',
                      onPressed: _deleting
                          ? null
                          : () => _scaffoldKey.currentState?.openEndDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<DetailHitoList>(
                future: _detail,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: PiloFamilyTheme.accentText,
                      ),
                    );
                  }
                  final detail = snapshot.data;
                  if (snapshot.hasError || detail == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No pudimos cargar este hito.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PiloFamilyTheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final voice = detail.voiceNote;
                  return TripHitoContent(
                    tourId: widget.login.tourSalesId,
                    hitoId: int.tryParse(widget.idHito),
                    detail: detail,
                    familyStyle: true,
                    voicePlayer: voice == null
                        ? null
                        : TripVoicePlayer(
                            key: ValueKey('voice-${widget.idHito}-${voice.id}'),
                            duration: voice.duration,
                            loadFile: () => _provider.readHitoVoice(
                              int.parse(widget.idHito),
                              widget.login.tourSalesId,
                              voice,
                            ),
                          ),
                    actions: widget.canModify ? _actions(detail) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
