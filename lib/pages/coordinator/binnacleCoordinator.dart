import 'package:papigiras_app/utils/coordinator_location_toggle.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/maps/trip_binnacle_timeline.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/pages/coordinator/detailbinnacleCoodinator.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';

class BitacoraCoordScreen extends StatefulWidget {
  const BitacoraCoordScreen({
    super.key,
    required this.login,
    this.controller,
    this.onHitoChanged,
  });

  final TourSales login;
  final TripMapController? controller;
  final VoidCallback? onHitoChanged;

  @override
  State<BitacoraCoordScreen> createState() => _BitacoraCoordScreenState();
}

class _BitacoraCoordScreenState extends State<BitacoraCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: PiloFamilyTheme.paper,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: TripBinnacleTimeline(
        tourId: widget.login.tourSalesId,
        controller: widget.controller,
        showAuthor: true,
        onOpenMap: _openMap,
        onOpenDetail: _openBinnacleDetail,
        familyHeader: (onRefresh) => PiloSectionBar(
          title: 'Bitácora',
          compact: true,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
          onBack: _back,
          actions: [
            IconButton(
              onPressed: onRefresh,
              tooltip: 'Actualizar bitácora',
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              tooltip: 'Abrir menú',
              icon: const Icon(Icons.menu_rounded),
            ),
          ],
        ),
      ),
    ),
  );

  void _back() {
    final navigation = FamilyNavigationScope.maybeOf(context);
    if (navigation != null) {
      navigation.back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _openMap(int id) {
    final navigation = FamilyNavigationScope.maybeOf(context);
    if (navigation != null) {
      navigation.openMap(id);
      return;
    }
    Navigator.of(context).push(
      buildCoordinatorRoute(
        TraceMapFullScreen(
          locationControl: const CoordinatorLocationToggle(compact: true),
          coordinatorId: widget.login.coordinatorId,
          tourCode: widget.login.tourSalesId,
          initialHitoId: id,
          edgeToEdge: true,
          onCreateHito: (location) async {
            final created = await showPiloNewHitoSheet(
              context,
              login: widget.login,
              initialLocation: location,
            );
            if (mounted && created == true) {
              widget.controller?.refresh();
              widget.onHitoChanged?.call();
            }
          },
          onOpenHito: _openBinnacleDetail,
        ),
      ),
    );
  }

  Future<void> _openBinnacleDetail(TripMapEntry entry) async {
    await Navigator.of(context).push(
      buildCoordinatorRoute(
        DetalleBitacoraCoordScreen(
          idHito: entry.id.toString(),
          login: widget.login,
          // Preserve the server's role/ownership decision, never infer it from
          // the name of the author or from who opened this presentation.
          canModify: entry.source.canModify,
          initialLocation:
              entry.position != null &&
                  HitoLocationDraft.isValidPoint(entry.position!)
              ? HitoLocationDraft(
                  point: entry.position!,
                  label: entry.source.binnacleUbicacion,
                )
              : null,
          onHitoChanged: widget.onHitoChanged,
        ),
      ),
    );
  }
}
