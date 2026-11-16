import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_coordinator_home.dart';
import 'package:papigiras_app/design/pilo_coordinator_activity.dart';
import 'package:papigiras_app/design/pilo_coordinator_summary.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/passenger_counter_session.dart';
import 'package:papigiras_app/design/special_diet_passengers.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/gallery/trip_gallery_screen.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorProfile.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/detailbinnacleCoodinator.dart';
import 'package:papigiras_app/pages/coordinator/listPassenger.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/ranking/coordinator_ranking_screen.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/coordinator_location_toggle.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/utils/page_navigation.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';
import 'package:provider/provider.dart';

class TravelCoordinatorDashboard extends StatefulWidget {
  const TravelCoordinatorDashboard({super.key, required this.login});

  final TourSales login;

  @override
  State<TravelCoordinatorDashboard> createState() =>
      _TravelCoordinatorDashboardState();
}

class _TravelCoordinatorDashboardState
    extends State<TravelCoordinatorDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  final _focus = ValueNotifier<(int?, int)>((null, 0));
  final _galleryRevision = ValueNotifier<int>(0);
  late final ValueNotifier<Future<CoordinatorTourDetail>> _tourSummary;
  late TripMapController _map;
  final _activity = ValueNotifier<Future<PiloCoordinatorActivity>?>(null);
  TripMapData? _activitySource;
  int _activityGeneration = 0;
  late PassengerCounterSession _counterSession;
  LocationService? _locationService;

  @override
  void initState() {
    super.initState();
    _counterSession = PassengerCounterSession(
      tourId: widget.login.tourSalesId,
      coordinatorId: widget.login.coordinatorId,
    );
    _tourSummary = ValueNotifier(_loadTourSummary());
    _loadMap();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final locationService = context.read<LocationService>();
      await locationService.initializeForCoordinatorSession();
      if (!mounted || locationService.lastError == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(locationService.lastError!)));
    });
  }

  Future<CoordinatorTourDetail> _loadTourSummary() =>
      _provider.getCoordinatorTourDetail(widget.login.tourSalesId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<LocationService>();
    if (identical(service, _locationService)) return;
    _locationService?.removeListener(_syncOwnBusSharing);
    _locationService = service;
    service.addListener(_syncOwnBusSharing);
    _syncOwnBusSharing();
  }

  void _syncOwnBusSharing() {
    final service = _locationService;
    if (!mounted || service?.activeTourId != widget.login.tourSalesId) return;
    _map.bus.setLocalSharing(
      coordinatorId: widget.login.coordinatorId,
      enabled: service!.isTracking,
      confirmed: service.confirmedPosition,
    );
  }

  void _loadMap() {
    _map = TripMapController(
      tourCode: widget.login.tourSalesId,
      provider: _provider,
    );
    _map.addListener(_updateActivity);
    _map.refresh();
  }

  @override
  void didUpdateWidget(covariant TravelCoordinatorDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.login.tourSalesId != widget.login.tourSalesId ||
        oldWidget.login.coordinatorId != widget.login.coordinatorId) {
      _counterSession = PassengerCounterSession(
        tourId: widget.login.tourSalesId,
        coordinatorId: widget.login.coordinatorId,
      );
      _map.removeListener(_updateActivity);
      _map.dispose();
      _activityGeneration++;
      _activitySource = null;
      _activity.value = null;
      _loadMap();
      _syncOwnBusSharing();
      _tourSummary.value = _loadTourSummary();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Derived counts depend on the running code. In debug, recompute after a
    // hot reload without restarting the app or discarding an open hito draft.
    _activitySource = null;
    _updateActivity();
  }

  @override
  void dispose() {
    _locationService?.removeListener(_syncOwnBusSharing);
    _focus.dispose();
    _galleryRevision.dispose();
    _tourSummary.dispose();
    _activityGeneration++;
    _activity.dispose();
    _map.removeListener(_updateActivity);
    _map.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _openMap([int? hitoId]) {
    _map.clearSelection();
    _focus.value = (hitoId, _focus.value.$2 + 1);
  }

  @override
  Widget build(BuildContext context) => FamilyNavigation(
    key: ValueKey((widget.login.tourSalesId, widget.login.coordinatorId)),
    pilo: true,
    immersiveMap: true,
    coordinatorTools: true,
    onMapOpened: _openMap,
    onMapRequested: _openMap,
    builders: {
      FamilySection.home: _buildHome,
      FamilySection.crew: (_) => BusCrewCoorScreen(login: widget.login),
      FamilySection.documents: (_) => DocumentCoordScreen(login: widget.login),
      FamilySection.diary: (_) => BitacoraCoordScreen(
        login: widget.login,
        controller: _map,
        onHitoChanged: _refreshHitos,
      ),
      FamilySection.map: (_) => ValueListenableBuilder<(int?, int)>(
        valueListenable: _focus,
        builder: (mapContext, focus, _) => TraceMapFullScreen(
          key: ValueKey(focus.$2),
          tourCode: widget.login.tourSalesId,
          controller: _map,
          initialHitoId: focus.$1,
          edgeToEdge: true,
          locationControl: const CoordinatorLocationToggle(compact: true),
          coordinatorId: widget.login.coordinatorId,
          onCreateHito: (point) =>
              _createHito(mapContext, initialLocation: point),
          onOpenHito: (entry) => _open(
            mapContext,
            DetalleBitacoraCoordScreen(
              idHito: entry.id.toString(),
              login: widget.login,
              canModify: entry.source.canModify,
              initialLocation:
                  entry.position != null &&
                      HitoLocationDraft.isValidPoint(entry.position!)
                  ? HitoLocationDraft(
                      point: entry.position!,
                      label: entry.source.binnacleUbicacion,
                    )
                  : null,
              onHitoChanged: _refreshHitos,
            ),
          ),
        ),
      ),
      FamilySection.gallery: (_) => ValueListenableBuilder<int>(
        valueListenable: _galleryRevision,
        builder: (_, revision, _) => TripGalleryScreen(
          key: ValueKey(revision),
          tourId: widget.login.tourSalesId,
          departure: widget.login.tourSalesInit,
        ),
      ),
    },
  );

  Widget _buildHome(BuildContext context) {
    final navigation = FamilyNavigationScope.maybeOf(context)!;
    void profile() => _open(context, const CoordinatorProfileScreen());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PiloFamilyTheme.paper,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        bottom: false,
        child: PiloCoordinatorHome(
          tour: widget.login,
          avatar: ProfilePhotoAvatar(
            radius: 28,
            onOpenProfile: profile,
            showEditBadge: true,
          ),
          locationToggle: const CoordinatorLocationToggle(compact: true),
          mapPreview: TripMapView(controller: _map, preview: true),
          onOpenMap: () => navigation.select(FamilySection.map),
          activity: _activityLabel(),
          passengers: _passengers(context),
          onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
          onNewHito: () => _createHito(context),
          onRanking: () => _open(
            context,
            CoordinatorRankingScreen(
              initialSeason: widget.login.seasonClient > 0
                  ? widget.login.seasonClient
                  : null,
              currentCoordinatorId: widget.login.coordinatorId,
            ),
          ),
          onCount: () => showPiloPassengerCounter(
            context,
            login: widget.login,
            session: _counterSession,
          ),
          onProfile: profile,
          onPassengers: () => _openRoster(context),
          onCrew: () => navigation.select(FamilySection.crew),
          onDocuments: () => navigation.select(FamilySection.documents),
        ),
      ),
    );
  }

  void _openRoster(BuildContext context) => _open(
    context,
    ListPassengerCoordScreen(login: widget.login),
    refreshSummary: true,
  );

  Widget _passengers(BuildContext context) =>
      ValueListenableBuilder<Future<CoordinatorTourDetail>>(
        valueListenable: _tourSummary,
        builder: (context, future, _) => FutureBuilder<CoordinatorTourDetail>(
          future: future,
          builder: (context, snapshot) => PiloCoordinatorSummary(
            detail: snapshot.data,
            loading: snapshot.connectionState == ConnectionState.waiting,
            hasError: snapshot.hasError,
            onRetry: () => _tourSummary.value = _loadTourSummary(),
            onOpenPassengers: () => _openRoster(context),
            onOpenDiets: () => _open(
              context,
              SpecialDietPassengersScreen(
                loadPassengers: () => _provider.getListPassenger(
                  widget.login.tourSalesId.toString(),
                ),
              ),
              refreshSummary: true,
            ),
          ),
        ),
      );

  Future<void> _createHito(
    BuildContext context, {
    HitoLocationDraft? initialLocation,
  }) async {
    final published = await showPiloNewHitoSheet(
      context,
      login: widget.login,
      initialLocation: initialLocation,
    );
    if (mounted && published == true) _refreshHitos();
  }

  // The list load belongs to the shared map. Selection/panning notifications
  // must not start photo reads again; only a new complete list invalidates it.
  void _updateActivity() {
    final data = _map.data;
    if (data == null) {
      if (!_map.loading && _map.error != null) {
        _activity.value = Future.value(
          const PiloCoordinatorActivity.unavailable(),
        );
      }
      return;
    }
    if (identical(data, _activitySource)) return;
    _activitySource = data;
    final generation = ++_activityGeneration;
    _activity.value = loadPiloCoordinatorActivity(
      tourId: widget.login.tourSalesId,
      coordinatorId: widget.login.coordinatorId,
      hitos: data.entries.map((entry) => entry.source),
      loadDetail: _provider.getHitoComplete,
      isCurrent: () => mounted && generation == _activityGeneration,
    );
  }

  Widget _activityLabel() =>
      ValueListenableBuilder<Future<PiloCoordinatorActivity>?>(
        valueListenable: _activity,
        builder: (_, future, _) => FutureBuilder<PiloCoordinatorActivity>(
          future: future,
          builder: (_, snapshot) {
            if (future == null ||
                snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Cargando tus aportes…');
            }
            final counts = snapshot.data;
            final hitos = counts?.hitoCount;
            final photos = counts?.photoCount;
            if (hitos == null) {
              return const Tooltip(
                message:
                    'Recuento por coordinador no disponible para esta gira.',
                child: Text('— hitos · — fotos'),
              );
            }
            final label =
                '$hitos ${hitos == 1 ? 'hito' : 'hitos'} · '
                '${photos ?? '—'} ${photos == 1 ? 'foto' : 'fotos'}';
            return Tooltip(
              message: photos == null
                  ? 'Tus hitos en esta gira. Recuento de fotos no disponible.'
                  : 'Tus aportes en esta gira',
              child: Text(
                label,
                key: const ValueKey('coordinator-own-activity'),
              ),
            );
          },
        ),
      );

  void _refreshHitos() {
    _map.refresh();
    _galleryRevision.value++;
  }

  Future<Object?> _open(
    BuildContext context,
    Widget destination, {
    bool refreshSummary = false,
  }) async {
    final navigator = FamilyNavigationScope.maybeOf(context)!.sessionNavigator;
    final result = await navigator.push(
      buildPapiRoute(InheritedTheme.captureAll(context, destination)),
    );
    if (mounted && refreshSummary) {
      _tourSummary.value = _loadTourSummary();
    }
    return result;
  }
}
