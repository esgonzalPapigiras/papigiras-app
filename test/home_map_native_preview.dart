// Explicit native visual QA only: never imported by main.dart.
// Build with -t test/home_map_native_preview.dart --dart-define=HOME_MAP_NATIVE_QA=true.
// Optional: HOME_MAP_QA_ROLE=coordinator and HOME_MAP_QA_ONLINE=true.
// HOME_MAP_QA_AUTOSWITCH=true switches guardian -> coordinator after 25 seconds.
// The top-right menu swaps guardian/coordinator without changing a saved session.
// Only public cartography uses the existing allow-listed map client. All API
// transport is rejected; identity, trip, bus, milestones and photos are fixtures.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:papigiras_app/design/family_home.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/design/pilo_coordinator_home.dart';
import 'package:papigiras_app/design/pilo_coordinator_summary.dart';
import 'package:papigiras_app/design/pilo_family_gallery_preview.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/coordinator_location_toggle.dart';
import 'package:provider/provider.dart';

import 'support/ux_demo_images.dart';

const _tourId = 910001;
const _online = bool.fromEnvironment('HOME_MAP_QA_ONLINE');
const _initialRole = String.fromEnvironment(
  'HOME_MAP_QA_ROLE',
  defaultValue: 'guardian',
);
final _today = DateTime.now();
String _date(int offset) => DateTime(
  _today.year,
  _today.month,
  _today.day + offset,
).toIso8601String().substring(0, 10);

class _NoApi extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw StateError('API transport disabled in home map native QA');
}

class _MapFixtureProvider extends CoordinatorProviders {
  _MapFixtureProvider() : super(client: LabApiClient(transport: _NoApi()));

  @override
  Future<List<PositionCoordinator>> uniqueID(String code) async => [
    PositionCoordinator(
      coordinatorId: _tourId,
      coordinatorName: 'Valentina',
      coordinatorLastname: 'Ejemplo LAB',
      latitude: -33.4489,
      longitude: -70.6693,
      recordedAt: _online
          ? DateTime.now().toUtc().subtract(const Duration(seconds: 5))
          : _today.subtract(const Duration(days: 1)).toUtc(),
    ),
  ];

  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String code) async => [
    _hito(910012, 'Llegamos a Santiago', -33.393, -70.785, -1),
    // Latest hito is deliberately away from the bus: QA must center the bus,
    // including its valid offline last location, rather than this newer hito.
    _hito(910013, 'Una pausa durante el viaje', -34.17, -70.74, 0),
  ];

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tour) async =>
      DetailHitoList(
        titulo: 'Un recuerdo de la gira',
        descripcion: 'Contenido ficticio para revisar el inicio.',
        images: [uxCityPhoto, uxParkPhoto, uxLagoonPhoto],
      );
}

ConsolidatedTourSalesDTO _hito(
  int id,
  String title,
  double latitude,
  double longitude,
  int dayOffset,
) => ConsolidatedTourSalesDTO(
  binnacleDetailId: id,
  binnacleTitulo: title,
  binnacleDescripcion: 'Hito ficticio de revisión visual.',
  binnacleUbicacion: 'Lugar de ejemplo',
  binnacleNotaCierre: '',
  binnacleLatitud: '$latitude',
  binnacleLongitud: '$longitude',
  binnacleHora: '16:20',
  binnacleFecha: _date(dayOffset),
  author: const HitoAuthor(
    coordinatorId: _tourId,
    name: 'Valentina',
    lastname: 'Ejemplo LAB',
  ),
  canModify: false,
);

class _FixtureLocation extends LocationService {
  @override
  bool get isTracking => _online;
  @override
  Future<void> initializeForCoordinatorSession() async {}
  @override
  Future<void> setSharingEnabled(bool enabled) async {}
}

Future<void> main() async {
  if (!const bool.fromEnvironment('HOME_MAP_NATIVE_QA')) {
    throw StateError('Explicit HOME_MAP_NATIVE_QA=true flag required.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = LabOfflineHttpOverrides();
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('es');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ChangeNotifierProvider<LocationService>(
      create: (_) => _FixtureLocation(),
      child: const _HomeMapPreview(),
    ),
  );
}

class _HomeMapPreview extends StatefulWidget {
  const _HomeMapPreview();
  @override
  State<_HomeMapPreview> createState() => _HomeMapPreviewState();
}

class _HomeMapPreviewState extends State<_HomeMapPreview> {
  final _provider = _MapFixtureProvider();
  final _tree = GlobalKey();
  late final TripMapController _guardianMap;
  late final TripMapController _coordinatorMap;
  bool _coordinator = _initialRole == 'coordinator';
  Timer? _reportTimer;
  Timer? _roleTimer;
  String? _lastReadyRole;

  final _detail = CoordinatorTourDetail.fromJson({
    'tourId': _tourId,
    'tourCode': 'BRC26910001A',
    'startDate': _date(-2),
    'endDate': _date(4),
    'status': 'ACTIVE',
    'studentCount': 8,
    'clientName': 'Colegio Horizonte LAB',
    'course': '3° Medio B',
    'season': _today.year,
    'assignmentId': _tourId,
    'passengerCountsBySex': {'M': 4, 'F': 4, 'AM': 1, 'AF': 1},
    'specialDietCounts': {'Vegetariana': 3},
  });

  @override
  void initState() {
    super.initState();
    _guardianMap = TripMapController(tourCode: _tourId, provider: _provider);
    _coordinatorMap = TripMapController(tourCode: _tourId, provider: _provider);
    unawaited(_guardianMap.refresh());
    unawaited(_coordinatorMap.refresh());
    _reportTimer = Timer.periodic(const Duration(seconds: 3), (_) => _report());
    if (const bool.fromEnvironment('HOME_MAP_QA_AUTOSWITCH') && !_coordinator) {
      _roleTimer = Timer(const Duration(seconds: 25), _swapRole);
    }
  }

  void _report() {
    final root = _tree.currentContext;
    if (root == null) return;
    final cameras = <Map<String, Object?>>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is FlutterMap && widget.mapController != null) {
        try {
          final camera = widget.mapController!.camera;
          cameras.add({
            'latitude': camera.center.latitude,
            'longitude': camera.center.longitude,
            'zoom': camera.zoom,
            'width': camera.nonRotatedSize.x,
            'height': camera.nonRotatedSize.y,
          });
        } catch (_) {
          // The camera may not be attached yet during a role transition.
        }
      }
      element.visitChildren(visit);
    }

    (root as Element).visitChildren(visit);
    final role = _coordinator ? 'coordinator' : 'guardian';
    final cameraReady = cameras.isNotEmpty;
    if (cameraReady && _lastReadyRole != role) {
      _lastReadyRole = role;
      debugPrint(
        'HOME_MAP_NATIVE_QA: $role map_camera_ready (synthetic data only)',
      );
    }
    unawaited(
      File(
        '${Directory.systemTemp.path}/home-map-native-report.json',
      ).writeAsString(
        jsonEncode({
          'fixtureOnly': true,
          'apiTransportDisabled': true,
          'role': role,
          'mapCameraReady': cameraReady,
          'busOnline': _online,
          'bus': {'latitude': -33.4489, 'longitude': -70.6693},
          'cameras': cameras,
        }),
      ),
    );
  }

  void _swapRole() => setState(() => _coordinator = !_coordinator);
  void _noop() {}

  @override
  void dispose() {
    _reportTimer?.cancel();
    _roleTimer?.cancel();
    _guardianMap.dispose();
    _coordinatorMap.dispose();
    _provider.dispose();
    super.dispose();
  }

  Widget _avatar(String initials) => Stack(
    clipBehavior: Clip.none,
    children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: PiloFamilyTheme.mint.withValues(alpha: .22),
        child: Text(
          initials,
          style: const TextStyle(
            color: PiloFamilyTheme.accentText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const Positioned(
        right: -2,
        bottom: -2,
        child: CircleAvatar(
          radius: 12,
          backgroundColor: PiloFamilyTheme.accentText,
          child: Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
        ),
      ),
    ],
  );

  Widget _mapStatus() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 6,
          color: _online
              ? PiloFamilyTheme.accentText
              : PiloFamilyTheme.secondary,
        ),
        const SizedBox(width: 5),
        Text(
          _online ? 'Ubicación del bus' : 'Última ubicación del bus',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 10),
        ),
      ],
    ),
  );

  Widget _guardian() => FamilyHome(
    key: const ValueKey('home-map-qa-guardian'),
    givenNames: 'SOFÍA',
    surnames: 'TORRES EJEMPLO',
    rut: 'LAB-910011',
    school: _detail.clientName,
    course: _detail.course,
    year: '${_detail.season}',
    departure: _detail.startDate,
    returnDate: _detail.endDate,
    tourCode: _detail.tourCode,
    avatar: _avatar('ST'),
    map: TripMapView(controller: _guardianMap, preview: true, onExpand: _noop),
    showNavigation: false,
    onMenu: _swapRole,
    latestHito: _guardianMap,
    latestHitoTitle: () =>
        _guardianMap.data?.entries.lastOrNull?.source.binnacleTitulo,
    galleryPreview: PiloFamilyGalleryPreview(
      controller: _guardianMap,
      onOpen: _noop,
    ),
    mapStatus: _mapStatus(),
    onMedical: _noop,
    onDiary: _noop,
    onCrew: _noop,
    onDocuments: _noop,
    onMap: _noop,
    onGallery: _noop,
    onTripDetails: _noop,
  );

  Widget _coordinatorHome() => PiloCoordinatorHome(
    key: const ValueKey('home-map-qa-coordinator'),
    tour: TourSales.fromCoordinatorTour(
      coordinator: const CoordinatorLogin(
        coordinatorId: _tourId,
        rut: 'LAB-C910001',
        name: 'Valentina',
        lastname: 'Ejemplo LAB',
        mustChangePassword: false,
        token: '',
      ),
      tour: _detail,
    ),
    avatar: _avatar('VE'),
    locationToggle: const CoordinatorLocationToggle(compact: true),
    passengers: PiloCoordinatorSummary(
      detail: _detail,
      onOpenPassengers: _noop,
      onOpenDiets: _noop,
    ),
    mapPreview: TripMapView(controller: _coordinatorMap, preview: true),
    activity: const Text('2 hitos · 6 fotos'),
    onOpenMap: _noop,
    onMenu: _swapRole,
    onProfile: _noop,
    onNewHito: _noop,
    onCount: _noop,
    onPassengers: _noop,
    onCrew: _noop,
    onDocuments: _noop,
    onRanking: _noop,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    key: _tree,
    debugShowCheckedModeBanner: false,
    theme: PiloFamilyTheme.theme(papiTheme()),
    locale: papiLocale,
    supportedLocales: papiSupportedLocales,
    localizationsDelegates: papiLocalizationsDelegates,
    builder: (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: child!,
    ),
    home: Scaffold(
      body: SafeArea(
        bottom: false,
        child: _coordinator ? _coordinatorHome() : _guardian(),
      ),
      bottomNavigationBar: FamilyNavigationBar(
        selected: FamilySection.home,
        onSelected: (_) {},
        pilo: true,
        coordinatorTools: _coordinator,
      ),
    ),
  );
}
