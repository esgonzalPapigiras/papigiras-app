import '../../navigation/family_journey.dart';
import '../../navigation/family_navigation.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/design/family_home.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/design/pilo_family_medical_preview.dart';
import 'package:papigiras_app/design/pilo_family_trip_details.dart';
import 'package:papigiras_app/design/pilo_family_gallery_preview.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';

class TravelFatherDashboard extends StatefulWidget {
  const TravelFatherDashboard({super.key, required this.login});
  final ResponseAttorney login;
  @override
  State<TravelFatherDashboard> createState() => _TravelFatherDashboardState();
}

class _TravelFatherDashboardState extends State<TravelFatherDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  TripMapController? _mapController;
  TripMapController get _map =>
      _mapController ??= (TripMapController(tourCode: widget.login.tourId!)
        ..refresh());

  @override
  void didUpdateWidget(covariant TravelFatherDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.login.tourId != widget.login.tourId) {
      _mapController?.dispose();
      _mapController = null;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _openMap(BuildContext context) {
    if (widget.login.tourId == null) {
      _noTour(context);
      return;
    }
    FamilyNavigationScope.maybeOf(context)?.select(FamilySection.map);
  }

  void _noTour(BuildContext context) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('No hay una gira asociada.')));

  @override
  Widget build(BuildContext context) => FamilyJourney(
    key: ValueKey((widget.login.tourId, widget.login.passengerIdentificacion)),
    login: widget.login,
    homeBuilder: _buildHome,
  );

  Widget _buildHome(BuildContext context) {
    void documents() =>
        FamilyNavigationScope.maybeOf(context)?.select(FamilySection.documents);
    void crew() =>
        FamilyNavigationScope.maybeOf(context)?.select(FamilySection.crew);
    void gallery() =>
        FamilyNavigationScope.maybeOf(context)?.select(FamilySection.gallery);
    void medical() =>
        showPiloFamilyMedicalPreview(context, login: widget.login);
    void details() => showPiloFamilyTripDetails(
      context,
      title: piloDestinationLabel(widget.login.tourSalesUuid ?? ''),
      school: [
        formatSchoolName(widget.login.tourName ?? ''),
        widget.login.tourCourse ?? '',
        widget.login.tourYear?.toString() ?? '',
      ].where((v) => v.trim().isNotEmpty).join(' · '),
      departure: widget.login.tourSalesdateInitial ?? '',
      returnDate: widget.login.tourSalesdateFinal ?? '',
      onDocuments: documents,
      onCrew: crew,
    );
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PiloFamilyTheme.paper,
      endDrawer: AppDrawerFather(login: widget.login),
      body: SafeArea(
        bottom: false,
        child: FamilyHome(
          showNavigation: false,
          latestHito: widget.login.tourId == null ? null : _map,
          latestHitoTitle: () {
            if (widget.login.tourId == null) return null;
            final data = _map.data;
            final id = data?.latestId;
            return id == null
                ? null
                : data?.entryById(id)?.source.binnacleTitulo;
          },
          latestHitoDate: () {
            if (widget.login.tourId == null) return null;
            final data = _map.data;
            final id = data?.latestId;
            return id == null ? null : data?.entryById(id)?.occurredAt;
          },
          galleryPreview: widget.login.tourId == null
              ? null
              : PiloFamilyGalleryPreview(controller: _map, onOpen: gallery),
          mapStatus: widget.login.tourId == null ? null : _mapStatus(),
          onTripDetails: details,
          onMenu: () => AppDrawerFather.showPiloSheet(
            context,
            login: widget.login,
            onTripDetails: details,
            onMedical: medical,
            onDocuments: documents,
            onCrew: crew,
          ),
          givenNames: widget.login.passengerName ?? '',
          surnames: widget.login.passengerApellidos ?? '',
          rut: widget.login.passengerIdentificacion ?? '',
          school: widget.login.tourName ?? '',
          course: widget.login.tourCourse ?? '',
          year: widget.login.tourYear?.toString() ?? '',
          departure: widget.login.tourSalesdateInitial ?? '',
          returnDate: widget.login.tourSalesdateFinal ?? '',
          tourCode: widget.login.tourSalesUuid ?? '',
          avatar: ProfilePhotoAvatar(radius: 28, passenger: widget.login),
          map: widget.login.tourId == null
              ? const Center(child: Text('No hay una gira asociada.'))
              : TripMapView(
                  controller: _map,
                  preview: true,
                  onExpand: () => _openMap(context),
                ),
          onMap: () => _openMap(context),
          onGallery: gallery,
          onMedical: medical,
          onDiary: () => FamilyNavigationScope.maybeOf(
            context,
          )?.select(FamilySection.diary),
          onCrew: crew,
          onDocuments: documents,
        ),
      ),
    );
  }

  Widget _mapStatus() => ListenableBuilder(
    listenable: _map.bus,
    builder: (context, _) {
      final bus = _map.bus;
      final present = bus.position != null;
      final label = present
          ? (bus.isRecent ? 'Ubicación del bus' : 'Última ubicación del bus')
          : 'Mapa de la gira';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (present)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bus.isRecent
                      ? PiloFamilyTheme.accentText
                      : PiloFamilyTheme.secondary,
                ),
              )
            else
              const Icon(
                Icons.map_outlined,
                size: 13,
                color: PiloFamilyTheme.secondary,
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
