import 'package:flutter/material.dart';
import 'package:papigiras_app/design/coordinator_dashboard.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/activities.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorProfile.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/listPassenger.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CoordinatorProviders _provider = CoordinatorProviders();
  late final Future<Map<String, int>> _passengerCountsFuture;

  @override
  void initState() {
    super.initState();
    _passengerCountsFuture = _provider
        .getCoordinatorTourDetail(widget.login.tourSalesId)
        .then((tour) => tour.passengerCountsBySex);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final locationService = context.read<LocationService>();
      await locationService.initializeForCoordinatorSession();
      if (!mounted || locationService.lastError == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locationService.lastError!)),
      );
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        bottom: false,
        child: CoordinatorDashboardView(
          tour: widget.login,
          passengerCounts: _passengerCountsFuture,
          onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
          onProfile: () => _open(const CoordinatorProfileScreen()),
          onNewHito: () => _open(HitoAddCoordScreen(login: widget.login)),
          onCounter: () => _open(CountDownCoordScreen(login: widget.login)),
          onPassengers: () =>
              _open(ListPassengerCoordScreen(login: widget.login)),
          onActivities: () => _open(ActivitiesCoordScreen(login: widget.login)),
          onMedicalRecords: () =>
              _open(MedicalCoordScreen(login: widget.login)),
          onCrew: () => _open(BusCrewCoorScreen(login: widget.login)),
          onDocuments: () => _open(DocumentCoordScreen(login: widget.login)),
          onDiary: () => _open(BitacoraCoordScreen(login: widget.login)),
        ),
      ),
      bottomNavigationBar: CoordinatorDashboardDock(
        onDiary: () => _open(BitacoraCoordScreen(login: widget.login)),
        onCrew: () => _open(BusCrewCoorScreen(login: widget.login)),
        onDocuments: () => _open(DocumentCoordScreen(login: widget.login)),
      ),
    );
  }

  Future<dynamic> _open(Widget destination) {
    return Navigator.of(context).push(_createRoute(destination));
  }

  Route<dynamic> _createRoute(Widget destination) {
    return PageRouteBuilder<dynamic>(
      transitionDuration: const Duration(milliseconds: 1000),
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0, 1);
        final tween = Tween(begin: begin, end: Offset.zero).chain(
          CurveTween(curve: Curves.ease),
        );
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }
}
