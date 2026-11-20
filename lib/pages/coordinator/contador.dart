import 'dart:async';
import '../../runtime/passenger_qr.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:zxing2/qrcode.dart' as zxing;
import 'package:papigiras_app/lab/media.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/passenger_counter_view.dart';
import 'package:papigiras_app/design/passenger_counter_session.dart';
import 'package:papigiras_app/design/pilo_quick_counter_view.dart';

Future<void> showPiloPassengerCounter(
  BuildContext context, {
  required TourSales login,
  PassengerCounterSession? session,
  Future<List<PassengerList>> Function(String)? passengerLoader,
  WidgetBuilder? qrScannerBuilder,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  enableDrag: false,
  backgroundColor: Colors.transparent,
  builder: (_) => CountDownCoordScreen(
    login: login,
    session: session,
    sheet: true,
    passengerLoader: passengerLoader,
    qrScannerBuilder: qrScannerBuilder,
  ),
);

class CountDownCoordScreen extends StatefulWidget {
  const CountDownCoordScreen({
    super.key,
    required this.login,
    this.passengerLoader,
    this.qrScannerBuilder,
    this.session,
    this.sheet = false,
  });
  final TourSales login;
  final PassengerCounterSession? session;
  final bool sheet;

  /// Explicit injection for synthetic QA. Normal navigation always uses the
  /// authenticated provider and the existing camera/gallery QR reader.
  final Future<List<PassengerList>> Function(String tourId)? passengerLoader;
  final WidgetBuilder? qrScannerBuilder;

  @override
  State<CountDownCoordScreen> createState() => _CountDownCoordScreenState();
}

class _CountDownCoordScreenState extends State<CountDownCoordScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CoordinatorProviders? _coordinatorProvider;
  List<Map<String, dynamic>> alumnos = [];
  bool _loading = true;
  bool _hasError = false;
  bool _scanning = false;
  String? _feedbackText;
  late final PassengerCounterSession _session;
  final _sheetController = DraggableScrollableController();
  late final AnimationController _sheetAnimation;
  bool _expanded = false;
  bool _closing = false;
  double _compactExtent = .4;

  @override
  void initState() {
    super.initState();
    // Own the animation here: the compact and full views use different scroll
    // positions, so a scroll-position-owned animation can be cancelled midway.
    _sheetAnimation = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (_sheetController.isAttached && !_closing) {
          _sheetController.jumpTo(_sheetAnimation.value);
        }
      });
    _session =
        widget.session?.belongsTo(
              widget.login.tourSalesId,
              widget.login.coordinatorId,
            ) ==
            true
        ? widget.session!
        : PassengerCounterSession(
            tourId: widget.login.tourSalesId,
            coordinatorId: widget.login.coordinatorId,
          );
    _fetchPassengers();
  }

  Future<void> _fetchPassengers() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final load =
          widget.passengerLoader ??
          (_coordinatorProvider ??= CoordinatorProviders()).getListPassenger;
      final pasajeros = await load(widget.login.tourSalesId.toString());
      if (!mounted) return;
      setState(() {
        alumnos = pasajeros.map((p) {
          final name = (p.passengerName ?? '').trim();
          final lastName = (p.passengerApellidos ?? '').trim();
          return {
            'id': p.passengerId.toString(),
            'nombre': [
              name,
              if (lastName.isNotEmpty &&
                  !name.toLowerCase().endsWith(lastName.toLowerCase()))
                lastName,
            ].where((part) => part.isNotEmpty).join(' '),
            'verificado':
                _session.verified[p.passengerId.toString()] ??
                p.passengerverificate,
          };
        }).toList();
        _session.quickCount = _session.quickCount.clamp(0, alumnos.length);
        _loading = false;
      });
    } catch (_) {
      // No exception payloads or passenger data in logs.
      if (mounted)
        setState(() {
          _loading = false;
          _hasError = true;
        });
    }
  }

  Future<void> _scanQRCode() async {
    if (_scanning || _loading || _hasError || alumnos.isEmpty) return;
    setState(() => _scanning = true);
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => Theme(
            data: PiloFamilyTheme.theme(Theme.of(context)),
            child:
                widget.qrScannerBuilder?.call(context) ?? const QRViewExample(),
          ),
        ),
      );
      if (!mounted || result == null)
        return; // Closing the reader isn't an error.
      if (result.trim().isEmpty) {
        _feedback('No se pudo leer el QR. Vuelve a escanearlo.');
      } else {
        _marcarAlumnoPorId(result.trim());
      }
    } catch (_) {
      if (mounted) {
        _feedback('No pudimos abrir el lector QR. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _resetCounter() async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: PiloFamilyTheme.theme(Theme.of(context)),
        child: AlertDialog.adaptive(
          title: const Text('¿Reiniciar el conteo?'),
          content: const Text(
            'Todos los pasajeros quedarán pendientes de verificar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reiniciar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      for (final alumno in alumnos) {
        alumno['verificado'] = false;
        _session.verified[alumno['id'] as String] = false;
      }
    });
    _feedback('Conteo reiniciado.');
  }

  void _feedback(String text) {
    setState(() => _feedbackText = text);
  }

  void _marcarAlumnoPorId(String idEscaneado) {
    final index = alumnos.indexWhere((a) {
      final hasTourPassengerId =
          a.containsKey('tourPassengerId') && a['tourPassengerId'] != null;
      return hasTourPassengerId
          ? a['tourPassengerId'].toString() == idEscaneado
          : a['id'].toString() == idEscaneado;
    });
    if (index == -1) {
      _feedback('Este QR no corresponde a un pasajero de esta gira.');
    } else if (alumnos[index]['verificado'] == true) {
      _feedback('${alumnos[index]['nombre']} ya está contabilizado.');
    } else {
      _togglePassenger(idEscaneado, true);
      _feedback('${alumnos[index]['nombre']}: contabilizado.');
    }
  }

  @override
  void dispose() {
    _sheetAnimation.dispose();
    _sheetController.dispose();
    _coordinatorProvider?.dispose();
    super.dispose();
  }

  void _togglePassenger(String id, bool value) => setState(() {
    final index = alumnos.indexWhere((a) => a['id'] == id);
    if (index >= 0) {
      alumnos[index]['verificado'] = value;
      _session.verified[id] = value;
    }
  });

  Future<bool> _resizeSheet(bool expand) async {
    if (!_sheetController.isAttached || _closing) return false;
    final target = expand ? .96 : _compactExtent;
    _sheetAnimation.stop(canceled: true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheetController.jumpTo(target);
    } else {
      _sheetAnimation.value = _sheetController.size;
      try {
        await _sheetAnimation
            .animateTo(
              target,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            )
            .orCancel;
      } on TickerCanceled {
        return false;
      }
    }
    return mounted && !_closing;
  }

  Future<void> _expandAndScan() async {
    final completed = await _resizeSheet(true);
    if (completed && mounted && ModalRoute.of(context)?.isCurrent == true) {
      await _scanQRCode();
    }
  }

  void _closeCounter() {
    if (_closing || !mounted || ModalRoute.of(context)?.isCurrent != true)
      return;
    _closing = true;
    _sheetAnimation.stop(canceled: true);
    Navigator.of(context).pop();
  }

  Widget _fullView([ScrollController? controller]) => PassengerCounterView(
    scrollController: controller,
    onBack: widget.sheet ? () => _resizeSheet(false) : null,
    passengers: alumnos
        .map(
          (a) => CounterPassenger(
            id: a['id'],
            name: (a['nombre'] as String).isEmpty
                ? 'Pasajero sin nombre'
                : a['nombre'],
            counted: a['verificado'] == true,
          ),
        )
        .toList(),
    loading: _loading,
    hasError: _hasError,
    scanning: _scanning,
    feedback: _feedbackText,
    onScan: _scanQRCode,
    onReset: _resetCounter,
    onRetry: _fetchPassengers,
    onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
    onToggle: _togglePassenger,
  );

  Widget _sheetBody(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final extraText = (MediaQuery.textScalerOf(context).scale(15) - 15) * 5;
      _compactExtent =
          ((300 + MediaQuery.paddingOf(context).bottom + extraText) /
                  bounds.maxHeight)
              .clamp(.32, .80);
      return NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.dragDetails != null) {
            _sheetAnimation.stop(canceled: true);
          }
          return false;
        },
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent <= .201) _closeCounter();
            final expanded = notification.extent > (_compactExtent + .96) / 2;
            if (_expanded != expanded) setState(() => _expanded = expanded);
            return false;
          },
          child: DraggableScrollableSheet(
            key: const ValueKey('passenger-counter-sheet'),
            controller: _sheetController,
            initialChildSize: _compactExtent,
            minChildSize: .20,
            maxChildSize: .96,
            snap: true,
            snapSizes: [_compactExtent],
            expand: false,
            shouldCloseOnMinExtent: false,
            builder: (context, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              child: Scaffold(
                key: _scaffoldKey,
                endDrawer: CoordinatorEndDrawer(login: widget.login),
                body: Column(
                  children: [
                    Semantics(
                      button: true,
                      label: _expanded
                          ? 'Contraer contador'
                          : 'Ampliar contador',
                      child: GestureDetector(
                        key: const ValueKey('counter-sheet-grabber'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _resizeSheet(!_expanded),
                        onVerticalDragUpdate: (details) {
                          _sheetAnimation.stop(canceled: true);
                          if (_sheetController.isAttached) {
                            _sheetController.jumpTo(
                              (_sheetController.size -
                                      details.delta.dy / bounds.maxHeight)
                                  .clamp(.20, .96),
                            );
                          }
                        },
                        onVerticalDragEnd: (details) {
                          if (!_sheetController.isAttached) return;
                          if (_sheetController.size < _compactExtent - .05) {
                            _closeCounter();
                          } else {
                            _resizeSheet(
                              details.primaryVelocity! < -200 ||
                                  (details.primaryVelocity! <= 200 &&
                                      _expanded),
                            );
                          }
                        },
                        child: SizedBox(
                          height: 44,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 34,
                              height: 4,
                              decoration: BoxDecoration(
                                color: PiloFamilyTheme.connectorLine,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: _expanded
                            ? _fullView(scrollController)
                            : PiloQuickCounterView(
                                scrollController: scrollController,
                                count: _session.quickCount,
                                total: alumnos.length,
                                loading: _loading,
                                hasError: _hasError,
                                onIncrement: () => setState(
                                  () => _session.quickCount =
                                      (_session.quickCount + 1).clamp(
                                        0,
                                        alumnos.length,
                                      ),
                                ),
                                onDecrement: () => setState(
                                  () => _session.quickCount =
                                      (_session.quickCount - 1).clamp(
                                        0,
                                        alumnos.length,
                                      ),
                                ),
                                onReset: () =>
                                    setState(() => _session.quickCount = 0),
                                onRetry: _fetchPassengers,
                                onExpand: () => _resizeSheet(true),
                                onScan: _expandAndScan,
                                onClose: _closeCounter,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: widget.sheet
        ? Builder(builder: _sheetBody)
        : Scaffold(
            key: _scaffoldKey,
            endDrawer: CoordinatorEndDrawer(login: widget.login),
            body: _fullView(),
          ),
  );
}

/// Extract identification only. No scanned URL is opened or fetched.
String? passengerIdFromQr(String payload) => passengerQrCodec.decode(payload);

// Retained for the original reference tests and existing internal callers.
String? labPassengerIdFromQr(String payload) => passengerIdFromQr(payload);

/// Decode the actual image locally, including simulator gallery fixtures.
Future<String> decodePassengerQrImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 1024,
    allowUpscaling: false,
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      final image = frame.image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null)
        throw const FormatException('No se pudo leer la imagen.');
      final data = rgba.buffer.asUint8List();
      final pixels = Int32List(image.width * image.height);
      for (var index = 0; index < pixels.length; index++) {
        final offset = index * 4;
        pixels[index] = data[offset + 3] == 0
            ? 0xffffff
            : (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];
      }
      final result = zxing.QRCodeReader().decode(
        zxing.BinaryBitmap(
          zxing.HybridBinarizer(
            zxing.RGBLuminanceSource(image.width, image.height, pixels),
          ),
        ),
      );
      final passenger = passengerIdFromQr(result.text);
      if (passenger == null)
        throw const FormatException('El QR no es un pasajero de Papigiras.');
      return passenger;
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Future<String> decodeLabPassengerQrImage(Uint8List bytes) =>
    decodePassengerQrImage(bytes);

class QRViewExample extends StatefulWidget {
  const QRViewExample({super.key, this.cameraBuilder, this.galleryImageLoader});

  /// Synthetic QA only; normal use keeps the native camera and gallery picker.
  final Widget Function(BuildContext, ValueChanged<String>)? cameraBuilder;
  final Future<Uint8List?> Function()? galleryImageLoader;

  @override
  State<QRViewExample> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final _cameraKey = GlobalKey(debugLabel: 'Papigiras QR camera');
  StreamSubscription<Barcode>? _subscription;
  QRViewController? _controller;
  bool _busy = false;
  bool _done = false;
  String? _message;
  bool _cameraUnavailable = false;

  void _cameraError(String message) {
    if (!mounted || _done || _cameraUnavailable) return;
    setState(() => _cameraUnavailable = true);
    _subscription?.cancel();
    _subscription = null;
    // QRView owns disposal; never use its controller once the view is removed.
    _controller = null;
  }

  void _created(QRViewController controller) {
    if (!mounted || _cameraUnavailable) return;
    _controller = controller;
    _subscription = controller.scannedDataStream.listen((barcode) async {
      if (_done || _busy || barcode.code == null) return;
      final id = passengerIdFromQr(barcode.code!);
      if (id == null) {
        if (mounted)
          setState(() => _message = 'El QR debe pertenecer a Papigiras.');
        return;
      }
      _done = true;
      try {
        await controller.pauseCamera();
      } catch (_) {}
      if (mounted) Navigator.pop(context, id);
    });
  }

  Future<void> _fromGallery() async {
    if (_busy || _done) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      try {
        await _controller?.pauseCamera();
      } catch (_) {}
      final Uint8List? bytes;
      if (widget.galleryImageLoader != null) {
        bytes = await widget.galleryImageLoader!();
      } else {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        bytes = await image?.readAsBytes();
      }
      if (!mounted || bytes == null) return;
      final id = await decodePassengerQrImage(bytes);
      _done = true;
      if (mounted) Navigator.pop(context, id);
    } catch (_) {
      if (mounted)
        setState(
          () => _message =
              'No se encontró un QR válido de Papigiras en la imagen.',
        );
    } finally {
      if (mounted && !_done) {
        setState(() => _busy = false);
        try {
          await _controller?.resumeCamera();
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // QRView owns and disposes the camera/controller.
    super.dispose();
  }

  Widget _unavailableCamera() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: PiloFamilyTheme.soft,
              child: Icon(
                Icons.no_photography_outlined,
                color: PiloFamilyTheme.ink,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cámara no disponible',
              style: PiloFamilyTheme.display(28),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes leer el código QR desde una imagen de tu galería. '
              'Si usas un teléfono, revisa el permiso de cámara en Ajustes.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 64,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
          style: IconButton.styleFrom(backgroundColor: PiloFamilyTheme.soft),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      title: Text('Lector QR', style: PiloFamilyTheme.display(32)),
    ),
    body: Column(
      children: [
        Expanded(
          child: _cameraUnavailable
              ? _unavailableCamera()
              : widget.cameraBuilder?.call(context, _cameraError) ??
                    QRView(
                      key: _cameraKey,
                      onQRViewCreated: _created,
                      formatsAllowed: const [BarcodeFormat.qrcode],
                      onCameraError: _cameraError,
                      onPermissionSet: (_, allowed) {
                        if (!allowed) _cameraError('permission-denied');
                      },
                      overlay: QrScannerOverlayShape(
                        borderColor: PiloFamilyTheme.mint,
                        borderRadius: 22,
                        borderLength: 30,
                        borderWidth: 8,
                        cutOutSize: 250,
                      ),
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_message!, textAlign: TextAlign.center),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : _fromGallery,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library),
                  label: const Text('Leer QR desde Galería'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
