import 'package:flutter/material.dart';
import '../dto/responseAttorney.dart';
import '../pages/attorney/tripulationbusfather.dart';
import '../pages/attorney/documentsfather.dart';
import '../pages/attorney/binnaclefather.dart';
import '../pages/attorney/TraceMapFullScreen.dart';
import '../gallery/trip_gallery_screen.dart';
import 'family_navigation.dart';

/// Role-specific destinations. No session, API or permission changes.
class FamilyJourney extends StatefulWidget {
  const FamilyJourney({
    super.key,
    required this.login,
    required this.homeBuilder,
  });
  final ResponseAttorney login;
  final WidgetBuilder homeBuilder;
  @override
  State<FamilyJourney> createState() => _FamilyJourneyState();
}

class _FamilyJourneyState extends State<FamilyJourney> {
  final _focus = ValueNotifier<(int?, int)>((null, 0));

  void _openMap([int? hitoId]) => _focus.value = (hitoId, _focus.value.$2 + 1);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FamilyNavigation(
    key: ValueKey((widget.login.tourId, widget.login.passengerIdentificacion)),
    pilo: true,
    immersiveMap: widget.login.tourId != null,
    onMapOpened: _openMap,
    onMapRequested: _openMap,
    builders: {
      FamilySection.home: widget.homeBuilder,
      FamilySection.crew: (_) => BusCrewFatherScreen(login: widget.login),
      FamilySection.documents: (_) => DocumentFatherScreen(login: widget.login),
      FamilySection.diary: (_) => BitacoraFatherScreen(login: widget.login),
      FamilySection.map: (_) => widget.login.tourId == null
          ? const _NoTrip()
          : ValueListenableBuilder<(int?, int)>(
              valueListenable: _focus,
              builder: (context, focus, _) => TraceMapFullScreen(
                key: ValueKey(focus.$2),
                tourCode: widget.login.tourId!,
                initialHitoId: focus.$1,
                edgeToEdge: true,
              ),
            ),
      FamilySection.gallery: (_) => widget.login.tourId == null
          ? const _NoTrip()
          : TripGalleryScreen(
              tourId: widget.login.tourId!,
              departure: widget.login.tourSalesdateInitial ?? '',
            ),
    },
  );
}

class _NoTrip extends StatelessWidget {
  const _NoTrip();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(
        onPressed: () => FamilyNavigationScope.maybeOf(context)?.back(),
      ),
    ),
    body: const Center(child: Text('No hay una gira asociada.')),
  );
}
