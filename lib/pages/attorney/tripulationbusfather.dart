import '../../navigation/family_navigation.dart';
import 'package:flutter/material.dart';
import '../../crew/trip_crew_view.dart';
import '../../design/pilo_family_theme.dart';
import '../../dto/responseAttorney.dart';
import '../../provider/coordinatorProvider.dart';
import '../../utils/app_drawer_father.dart';
import '../../utils/page_navigation.dart';
import 'indexFather.dart';

class BusCrewFatherScreen extends StatefulWidget {
  const BusCrewFatherScreen({super.key, required this.login, this.provider});
  final ResponseAttorney login;
  final CoordinatorProviders? provider;
  @override
  State<BusCrewFatherScreen> createState() => _BusCrewFatherScreenState();
}

class _BusCrewFatherScreenState extends State<BusCrewFatherScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  late final CoordinatorProviders _provider =
      widget.provider ?? CoordinatorProviders();
  String? _drawerImage;
  @override
  void initState() {
    super.initState();
    _loadDrawerImage();
  }

  Future<void> _loadDrawerImage() async {
    try {
      final photo = await _provider.getPicturePassenger(
        '${widget.login.passengerIdentificacion}',
        '${widget.login.tourId}',
      );
      if (mounted)
        setState(() => _drawerImage = photo.image.isEmpty ? null : photo.image);
    } catch (_) {
      /* Drawer avatar has its own existing fallback. */
    }
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  void _back() {
    final navigation = FamilyNavigationScope.maybeOf(context);
    if (navigation != null) {
      navigation.back();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        buildPapiRoute(TravelFatherDashboard(login: widget.login)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffold,
      backgroundColor: PiloFamilyTheme.paper,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: null,
        imageUrl: _drawerImage,
      ),
      body: SafeArea(
        bottom: false,
        child: TripCrewView(
          tourId: widget.login.tourId ?? 0,
          provider: _provider,
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
