import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:papigiras_app/design/pilo_hito_publish_feedback.dart';
import 'package:papigiras_app/design/pilo_hito_discard_dialog.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/utils/coordinator_reauthentication_dialog.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/pilo_hito_location_picker.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/page_navigation.dart';
import 'package:papigiras_app/voice/hito_publisher.dart';
import 'package:papigiras_app/voice/local_voice_recorder.dart';
import 'package:papigiras_app/voice/trip_voice_recorder.dart';
import 'package:papigiras_app/voice/voice_note_draft.dart';
import 'package:papigiras_app/voice/voice_recorder_port.dart';

/// The existing composer, presented above home. Its publisher and attachments
/// are shared with the full-page flow; the sheet never publishes on dismissal.
Future<bool?> showPiloNewHitoSheet(
  BuildContext context, {
  required TourSales login,
  CoordinatorProviders? provider,
  VoiceRecorderPort? recorder,
  ImagePicker? picker,
  Widget Function(VoiceNoteDraft)? voicePreviewBuilder,
  HitoLocationDraft? initialLocation,
}) => showModalBottomSheet<bool>(
  context: context,
  useSafeArea: true,
  useRootNavigator: true,
  isScrollControlled: true,
  // Route-level dragging/barrier dismissal would bypass the draft guard.
  // The scroll sheet can still resize; the visible close action is guarded.
  enableDrag: false,
  isDismissible: false,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black38,
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: DraggableScrollableSheet(
      key: const ValueKey('hito-create-sheet'),
      expand: false,
      initialChildSize: .84,
      minChildSize: .62,
      maxChildSize: .96,
      snap: true,
      snapSizes: const [.62, .84, .96],
      shouldCloseOnMinExtent: false,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: HitoAddCoordScreen(
          login: login,
          provider: provider,
          recorder: recorder,
          picker: picker,
          voicePreviewBuilder: voicePreviewBuilder,
          initialLocation: initialLocation,
          asSheet: true,
          scrollController: controller,
        ),
      ),
    ),
  ),
);

class HitoAddCoordScreen extends StatefulWidget {
  const HitoAddCoordScreen({
    super.key,
    required this.login,
    this.provider,
    this.recorder,
    this.picker,
    this.voicePreviewBuilder,
    this.initialLocation,
    this.asSheet = false,
    this.scrollController,
  });
  final TourSales login;
  final CoordinatorProviders? provider;
  final VoiceRecorderPort? recorder;
  final ImagePicker? picker;
  final Widget Function(VoiceNoteDraft)? voicePreviewBuilder;
  final HitoLocationDraft? initialLocation;
  final bool asSheet;
  final ScrollController? scrollController;
  @override
  State<HitoAddCoordScreen> createState() => _AddHitoScreenState();
}

class _AddHitoScreenState extends State<HitoAddCoordScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final CoordinatorProviders _provider =
      widget.provider ?? CoordinatorProviders(preserveHitoDraft: true);
  late final HitoPublisher _publisher = HitoPublisher(_provider);
  late final VoiceRecorderPort _recorder =
      widget.recorder ?? LocalVoiceRecorder();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  final List<XFile> _photos = [];
  VoiceNoteDraft? _voice;
  bool _recording = false;
  bool _picking = false;
  bool _checkingSession = false;
  bool _locationReady = false;
  bool _choosingLocation = false;
  bool _locationAdjusted = false;
  String? _error;
  RequestHito? _submitted;
  bool _allowSheetClose = false;
  bool _confirmingClose = false;
  LabRoutePoint _position = LabSyntheticLocation.instance.current;
  bool get _locked =>
      _publisher.busy ||
      _checkingSession ||
      _publisher.createdHitoId != null ||
      _publisher.requiresReview;
  bool get _closeBlocked =>
      _publisher.busy ||
      _checkingSession ||
      _picking ||
      _recording ||
      _choosingLocation;
  bool get _hasDraft =>
      _title.text.isNotEmpty ||
      _description.text.isNotEmpty ||
      _photos.isNotEmpty ||
      _voice != null ||
      _locationAdjusted;

  Future<void> _requestClose() async {
    if (_closeBlocked || _confirmingClose) return;
    if (_hasDraft && !_publisher.completed) {
      _confirmingClose = true;
      final partial =
          _publisher.createdHitoId != null || _publisher.requiresReview;
      final discard = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black38,
        builder: (_) => PiloHitoDiscardDialog(partial: partial),
      );
      _confirmingClose = false;
      if (!mounted || discard != true) return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _allowSheetClose = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _publisher.addListener(_changed);
    unawaited(_restoreLocation());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreLocation() async {
    try {
      final initial = widget.initialLocation;
      if (initial == null) await LabSyntheticLocation.instance.restore();
      if (!mounted) return;
      setState(() {
        _position = initial == null
            ? LabSyntheticLocation.instance.current
            : LabRoutePoint(
                initial.point.latitude,
                initial.point.longitude,
                initial.label,
              );
        _locationReady = true;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'No pudimos cargar la ubicación del laboratorio. Inténtalo de nuevo.',
        );
    }
  }

  Future<void> _adjustLocation() async {
    if (_locked ||
        _picking ||
        _recording ||
        _choosingLocation ||
        !_locationReady)
      return;
    FocusScope.of(context).unfocus();
    setState(() => _choosingLocation = true);
    try {
      final selected = await showPiloHitoLocationPicker(
        context,
        initial: HitoLocationDraft(
          point: _position.latLng,
          label: _position.address,
        ),
      );
      if (!mounted || selected == null) return;
      setState(() {
        _locationAdjusted =
            _locationAdjusted || selected.point != _position.latLng;
        // This is the hito draft only. Never move the shared bus location.
        _position = LabRoutePoint(
          selected.point.latitude,
          selected.point.longitude,
          selected.label,
        );
      });
    } finally {
      if (mounted) setState(() => _choosingLocation = false);
    }
  }

  Future<void> _pick(bool camera) async {
    if (_locked || _picking || _recording) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final selected = camera
          ? [
              await _picker.pickImage(source: ImageSource.camera),
            ].whereType<XFile>().toList()
          : await _picker.pickMultiImage();
      if (!mounted) return;
      setState(() => _photos.addAll(selected));
    } catch (_) {
      if (mounted)
        setState(
          () => _error = camera
              ? 'No pudimos abrir la cámara. Revisa su permiso o elige fotos de la galería.'
              : 'No pudimos abrir la galería. Revisa su permiso y vuelve a intentarlo.',
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  RequestHito _request() {
    final now = DateTime.now();
    final chileTime = now.toUtc().add(const Duration(hours: -3));
    return RequestHito(
      titulo: _title.text.trim(),
      descripcion: _description.text.trim(),
      ubicacion: _position.address,
      notaCierre: '',
      latitud: _position.latitude.toString(),
      longitud: _position.longitude.toString(),
      hora: DateFormat('HH:mm').format(chileTime),
      idTour: widget.login.tourSalesId,
      fecha: DateFormat('dd/MM/yyyy').format(now),
    );
  }

  Future<void> _requestRenewal() async {
    if (!mounted) return;
    setState(() => _checkingSession = true);
    try {
      final renewed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CoordinatorReauthenticationDialog(
          provider: _provider,
          expectedTour: widget.login,
        ),
      );
      if (!mounted) return;
      if (renewed == true) {
        setState(() => _error = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión renovada. Puedes publicar tu hito.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingSession = false);
    }
  }

  Future<bool> _checkSessionBeforePublishing() async {
    setState(() => _checkingSession = true);
    try {
      final active = await _provider.hasHitoSession(widget.login.coordinatorId);
      if (!mounted) return false;
      if (!active) {
        await _requestRenewal();
        // Authentication never submits or replays a mutation automatically.
        return false;
      }
      return true;
    } finally {
      if (mounted) setState(() => _checkingSession = false);
    }
  }

  Future<void> _publish() async {
    if (_publisher.busy ||
        _checkingSession ||
        _publisher.completed ||
        _recording ||
        _picking ||
        _choosingLocation ||
        !_locationReady ||
        _publisher.requiresReview ||
        !_form.currentState!.validate())
      return;
    if (!await _checkSessionBeforePublishing() || !mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    _submitted ??= _request();
    final navigator = Navigator.of(context);
    final dialog = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AnimatedBuilder(
          animation: _publisher,
          builder: (context, _) =>
              PiloHitoPublishingFeedback(progress: _publisher.progress),
        ),
      ),
    );
    unawaited(navigator.push(dialog));
    try {
      await _publisher.publish(
        hito: _submitted!,
        photos: List.unmodifiable(_photos),
        voice: _voice,
      );
      if (!mounted) return;
      if (dialog.isActive) navigator.removeRoute(dialog);
      unawaited(HapticFeedback.lightImpact());
      ScaffoldMessenger.of(context).showSnackBar(piloHitoPublishedSnackBar());
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      if (dialog.isActive) navigator.removeRoute(dialog);
      final authorizationRejected =
          error is LabApiException &&
          (error.statusCode == 401 || error.statusCode == 403);
      final needsRenewal =
          authorizationRejected &&
          (error.statusCode == 401 ||
              !await _provider.hasHitoSession(widget.login.coordinatorId));
      if (!mounted) return;
      setState(() {
        if (_publisher.createdHitoId == null && !_publisher.requiresReview) {
          _submitted = null;
        }
        if (needsRenewal) {
          _error = 'Tu sesión venció. Vuelve a ingresar; tu hito sigue aquí.';
        } else if (authorizationRejected) {
          _error =
              'Tu cuenta no tiene permiso para publicar en esta gira. Conservamos tus textos y archivos.';
        } else if (_publisher.creationOutcomeUnknown) {
          _error =
              'No pudimos confirmar si se guardó el hito. Revisa la bitácora antes de volver a publicarlo.';
        } else if (_publisher.photosOutcomeUnknown) {
          _error =
              'El hito quedó guardado, pero no pudimos confirmar las fotos. Revisa la bitácora antes de volver a adjuntarlas.';
        } else if (_publisher.createdHitoId != null) {
          _error =
              'El hito quedó guardado, pero faltan archivos por enviar. Puedes reintentar sin crear otro hito.';
        } else {
          _submitted = null;
          _error =
              'No pudimos publicar el hito. Tus textos y archivos siguen aquí; vuelve a intentarlo.';
        }
      });
      if (needsRenewal && !_publisher.requiresReview) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) await _requestRenewal();
      }
    }
  }

  @override
  void dispose() {
    _publisher.removeListener(_changed);
    _publisher.dispose();
    _title.dispose();
    _description.dispose();
    final voice = _voice;
    unawaited(() async {
      try {
        await _recorder.cancel();
      } catch (_) {
        /* Best effort cleanup. */
      }
      try {
        if (voice != null) await _recorder.discard(voice);
      } catch (_) {
        /* No raw file errors. */
      }
      if (widget.recorder == null) await _recorder.dispose();
    }());
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  // Keep the current server contract until its explicit upgrade is approved.
  // Existing longer titles remain editable in the separate edit form.
  static const _newTitleMaxLength = 60;
  static const _descriptionMaxLength = 140;

  Widget _textField({required bool title}) {
    final controller = title ? _title : _description;
    final label = title ? 'Título' : 'Descripción';
    final limit = title ? _newTitleMaxLength : _descriptionMaxLength;
    return _group(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PiloFamilyTheme.secondary,
                  ),
                ),
              ),
              Text(
                '${title ? value.text.characters.length : value.text.length} / $limit',
                key: ValueKey(
                  title ? 'hito-title-counter' : 'hito-description-counter',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: PiloFamilyTheme.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          key: ValueKey(title ? 'hito-add-title' : 'hito-add-description'),
          controller: controller,
          enabled: !_locked,
          minLines: title ? 1 : 2,
          maxLines: title ? 1 : 3,
          maxLength: limit,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: title
              ? TextInputAction.next
              : TextInputAction.newline,
          keyboardType: title ? TextInputType.text : TextInputType.multiline,
          style: const TextStyle(fontSize: 17, height: 1.3),
          decoration: InputDecoration(
            hintText: title
                ? 'Un nombre para este momento'
                : 'Cuéntales cómo va la gira…',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: PiloFamilyTheme.secondary,
            ),
            isDense: true,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            counterText: '',
            errorMaxLines: 2,
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty)
              return title ? 'Escribe un título.' : 'Escribe una descripción.';
            final length = title ? text.characters.length : text.length;
            if (length > limit) return 'Usa hasta $limit caracteres.';
            // A single visible emoji may contain several Unicode points.
            // Respect the stored title budget without splitting that emoji.
            if (title && text.runes.length > 255) {
              return 'Simplifica los emojis o símbolos del título.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _group({required List<Widget> children}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: PopScope<bool>(
      canPop: _allowSheetClose || _publisher.completed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: !widget.asSheet,
        backgroundColor: PiloFamilyTheme.paper,
        body: SafeArea(
          top: !widget.asSheet,
          bottom: false,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              controller: widget.scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.asSheet) ...[
                    Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        decoration: BoxDecoration(
                          color: PiloFamilyTheme.connectorPast,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Nuevo hito',
                              style: PiloFamilyTheme.display(28),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('hito-sheet-close'),
                            tooltip: 'Cerrar',
                            style: IconButton.styleFrom(
                              backgroundColor: PiloFamilyTheme.soft,
                            ),
                            onPressed: _closeBlocked ? null : _requestClose,
                            icon: const Icon(Icons.close_rounded, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    PiloSectionBar(
                      title: 'Nuevo hito',
                      compact: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      onBack: _closeBlocked ? null : _requestClose,
                    ),
                  _textField(title: true),
                  const SizedBox(height: 10),
                  _textField(title: false),
                  const SizedBox(height: 12),
                  _group(
                    children: [
                      const Text(
                        'Fotos',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: PiloFamilyTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked =
                              constraints.maxWidth < 260 ||
                              MediaQuery.textScalerOf(context).scale(16) > 22;
                          final width = stacked
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 10) / 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: width,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('hito-add-camera'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: PiloFamilyTheme.accentText,
                                    backgroundColor: PiloFamilyTheme.paper,
                                    side: BorderSide.none,
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _locked || _picking || _recording
                                      ? null
                                      : () => _pick(true),
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Cámara'),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('hito-add-gallery'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: PiloFamilyTheme.accentText,
                                    backgroundColor: PiloFamilyTheme.paper,
                                    side: BorderSide.none,
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _locked || _picking || _recording
                                      ? null
                                      : () => _pick(false),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Galería'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (_photos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: List.generate(
                              _photos.length,
                              (index) => SizedBox(
                                width: 96,
                                height: 96,
                                key: ValueKey('hito-add-photo-$index'),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        File(_photos[index].path),
                                        fit: BoxFit.cover,
                                        cacheWidth: 300,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                              color: tripPaper,
                                              child: Icon(
                                                Icons.hide_image_outlined,
                                                color: tripMuted,
                                              ),
                                            ),
                                      ),
                                    ),
                                    if (!_locked)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          key: ValueKey(
                                            'hito-remove-photo-$index',
                                          ),
                                          tooltip: 'Eliminar foto ${index + 1}',
                                          onPressed: () => setState(
                                            () => _photos.removeAt(index),
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: tripInk,
                                          ),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TripVoiceRecorder(
                    compact: true,
                    value: _voice,
                    recorder: _recorder,
                    enabled: !_locked && !_picking,
                    previewBuilder: widget.voicePreviewBuilder,
                    onChanged: (value) => setState(() => _voice = value),
                    onRecordingChanged: (value) =>
                        setState(() => _recording = value),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const ValueKey('hito-adjust-location'),
                    onPressed:
                        _locked || _picking || _recording || _choosingLocation
                        ? null
                        : _locationReady
                        ? _adjustLocation
                        : _restoreLocation,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PiloFamilyTheme.ink,
                      side: BorderSide.none,
                      backgroundColor: PiloFamilyTheme.soft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 22,
                          color: PiloFamilyTheme.accentText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ubicación del hito',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _locationReady
                                    ? _position.address
                                    : 'Cargando ubicación…',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: PiloFamilyTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _locationReady ? 'Ajustar' : 'Reintentar',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PiloFamilyTheme.accentText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          key: const ValueKey('hito-add-error'),
                          style: const TextStyle(
                            color: Color(0xFF9D2525),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _publisher.requiresReview
                ? OutlinedButton.icon(
                    onPressed: () {
                      final route = buildPapiRoute(
                        BitacoraCoordScreen(login: widget.login),
                      );
                      if (widget.asSheet) {
                        // Inspect uncertain results without losing this draft.
                        Navigator.of(context).push(route);
                      } else {
                        Navigator.of(context).pushReplacement(route);
                      }
                    },
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Ver bitácora'),
                  )
                : FilledButton.icon(
                    key: const ValueKey('hito-add-publish'),
                    onPressed:
                        _publisher.busy ||
                            _checkingSession ||
                            _recording ||
                            _picking ||
                            !_locationReady
                        ? null
                        : _publish,
                    style: FilledButton.styleFrom(
                      backgroundColor: PiloFamilyTheme.mint,
                      foregroundColor: PiloFamilyTheme.ink,
                      minimumSize: const Size(0, 52),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _publisher.createdHitoId == null
                          ? 'Publicar hito'
                          : 'Reintentar envío',
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
