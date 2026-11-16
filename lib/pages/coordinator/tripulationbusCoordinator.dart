import 'package:flutter/material.dart';
import '../../crew/trip_crew_view.dart';
import '../../design/pilo_family_theme.dart';
import '../../navigation/family_navigation.dart';
import '../../dto/TourSales.dart';
import '../../provider/coordinatorProvider.dart';
import '../../utils/coordinator_widgets.dart';

class BusCrewCoorScreen extends StatefulWidget {
  const BusCrewCoorScreen({super.key, required this.login, this.provider});
  final TourSales login;
  final CoordinatorProviders? provider;
  @override
  State<BusCrewCoorScreen> createState() => _BusCrewCoorScreenState();
}

class _BusCrewCoorScreenState extends State<BusCrewCoorScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      FamilyNavigationScope.maybeOf(context)?.back();
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffold,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        bottom: false,
        child: TripCrewView(
          tourId: widget.login.tourSalesId,
          provider: widget.provider,
          piloHeader: (refresh) => PiloSectionBar(
            title: 'Tripulación',
            subtitle: 'Equipo a cargo de la gira',
            padding: const EdgeInsets.only(bottom: 12),
            onBack: _back,
            actions: [
              IconButton(
                tooltip: 'Actualizar tripulación',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Abrir menú',
                onPressed: () => _scaffold.currentState?.openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
