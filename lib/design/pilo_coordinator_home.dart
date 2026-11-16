import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/design/family_home.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/pilo_trip_progress.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';

/// Coordinator's work surface. Shared trip views remain in the bottom dock.
class PiloCoordinatorHome extends StatelessWidget {
  const PiloCoordinatorHome({
    super.key,
    required this.tour,
    required this.avatar,
    required this.locationToggle,
    required this.passengers,
    required this.mapPreview,
    required this.activity,
    required this.onOpenMap,
    required this.onMenu,
    required this.onProfile,
    required this.onNewHito,
    required this.onCount,
    required this.onPassengers,
    required this.onCrew,
    required this.onDocuments,
    this.onRanking,
  });

  final TourSales tour;
  final Widget avatar;
  final Widget locationToggle;
  final Widget passengers;
  final Widget mapPreview;
  final Widget activity;
  final VoidCallback onOpenMap;
  final VoidCallback onMenu;
  final VoidCallback onProfile;
  final VoidCallback onNewHito;
  final VoidCallback onCount;
  final VoidCallback onPassengers;
  final VoidCallback onCrew;
  final VoidCallback onDocuments;
  final VoidCallback? onRanking;

  String get _name => formatStudentName(tour.tourTripulationNameId, null);
  String get _trip => [
    formatSchoolName(tour.nameClient),
    tour.courseClient.trim(),
    if (tour.seasonClient > 0) '${tour.seasonClient}',
  ].where((part) => part.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final tripTitle = piloDestinationLabel(tour.tourCode);
    return LayoutBuilder(
      builder: (context, bounds) {
        final narrow = bounds.maxWidth < 350;
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const ValueKey('coordinator-home-toolbar'),
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    key: const ValueKey('coordinator-home-profile'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: onProfile,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name.isEmpty ? 'Mi perfil' : _name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PiloFamilyTheme.display(narrow ? 21 : 24),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Coordinador/a · Mi perfil',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              height: 1.3,
                              color: PiloFamilyTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Menú de la cuenta',
                  style: IconButton.styleFrom(
                    backgroundColor: PiloFamilyTheme.soft,
                    minimumSize: const Size.square(44),
                  ),
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu_rounded, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tripTitle,
                    style: PiloFamilyTheme.display(narrow ? 29 : 32),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('coordinator-trip-details'),
                  tooltip: 'Información de la gira',
                  style: IconButton.styleFrom(
                    backgroundColor: PiloFamilyTheme.soft,
                    minimumSize: const Size.square(44),
                  ),
                  onPressed: () => _showDetails(context, tripTitle),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                ),
              ],
            ),
            if (_trip.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                _trip,
                key: const ValueKey('home-trip-title'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.4,
                  color: PiloFamilyTheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            PiloTripProgress(
              departure: tour.tourSalesInit,
              returnDate: tour.tourSalesFinal,
              compact: true,
            ),
            const SizedBox(height: 16),
            passengers,
            const SizedBox(height: 12),
            SizedBox(
              key: const ValueKey('coordinator-home-map-preview'),
              height: largeText ? 180 : 146,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    mapPreview,
                    Positioned(top: 7, left: 12, child: locationToggle),
                    Positioned(
                      right: 12,
                      bottom: 10,
                      child: FilledButton(
                        key: const ValueKey('coordinator-home-open-map'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: PiloFamilyTheme.ink,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: onOpenMap,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Abrir mapa'),
                            SizedBox(width: 7),
                            Icon(Icons.north_east_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        final actions = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onRanking != null)
              TextButton.icon(
                key: const ValueKey('coordinator-home-ranking'),
                style: TextButton.styleFrom(
                  foregroundColor: PiloFamilyTheme.accentText,
                  minimumSize: const Size(44, 44),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: onRanking,
                icon: const Icon(Icons.emoji_events_outlined, size: 19),
                label: const Row(
                  children: [
                    Expanded(child: Text('Ranking de temporada')),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            _actions(stacked: largeText),
          ],
        );
        // Keep creation within thumb reach; small screens and accessibility
        // text can scroll the complete surface without hiding any tool.
        final scrollAll = bounds.maxHeight < 430 || largeText;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: scrollAll
                ? SingleChildScrollView(
                    key: const PageStorageKey('coordinator-home-scroll'),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                    child: Column(
                      children: [content, const SizedBox(height: 12), actions],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          key: const PageStorageKey('coordinator-home-scroll'),
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                          child: content,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                        child: actions,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _actions({required bool stacked}) {
    final create = Material(
      color: PiloFamilyTheme.mint,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('home-new-hito'),
        onTap: onNewHito,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nuevo hito',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    DefaultTextStyle(
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        height: 1.3,
                        color: PiloFamilyTheme.ink,
                      ),
                      child: activity,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const CircleAvatar(
                radius: 20,
                backgroundColor: PiloFamilyTheme.ink,
                child: Icon(Icons.add_rounded, size: 25, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
    final counter = Material(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('home-action-count'),
        onTap: onCount,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded, size: 24),
              SizedBox(height: 6),
              Text(
                'Contador',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [create, const SizedBox(height: 8), counter],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: create),
          const SizedBox(width: 8),
          SizedBox(width: 86, child: counter),
        ],
      ),
    );
  }

  String _date(String value) {
    final date = parseTripMapDate(value, '00:00');
    return date == null
        ? 'Por confirmar'
        : DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _showDetails(BuildContext context, String tripTitle) async {
    final fonts = Theme.of(context).textTheme;
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PiloFamilyTheme.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tripTitle, style: fonts.titleLarge),
                if (_trip.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_trip, style: fonts.bodyMedium),
                ],
                const SizedBox(height: 16),
                PiloTripDates(
                  departure: _date(tour.tourSalesInit),
                  returnDate: _date(tour.tourSalesFinal),
                ),
                const SizedBox(height: 16),
                PiloHomeAction(
                  title: _name.isEmpty ? 'Mi perfil' : _name,
                  subtitle: 'Mi perfil de coordinador',
                  leadingIcon: Icons.person_outline_rounded,
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  color: PiloFamilyTheme.soft,
                  onTap: () => Navigator.pop(sheetContext, onProfile),
                ),
                const SizedBox(height: 8),
                PiloHomeAction(
                  key: const ValueKey('home-action-bus'),
                  title: 'Tripulación',
                  leadingIcon: Icons.directions_bus_outlined,
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  color: PiloFamilyTheme.soft,
                  onTap: () => Navigator.pop(sheetContext, onCrew),
                ),
                const SizedBox(height: 8),
                PiloHomeAction(
                  key: const ValueKey('trip-details-documents'),
                  title: 'Documentos',
                  leadingIcon: Icons.folder_outlined,
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  color: PiloFamilyTheme.soft,
                  onTap: () => Navigator.pop(sheetContext, onDocuments),
                ),
                const SizedBox(height: 8),
                PiloHomeAction(
                  key: const ValueKey('home-account-menu'),
                  title: 'Menú de la cuenta',
                  leadingIcon: Icons.menu,
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  color: PiloFamilyTheme.soft,
                  onTap: () => Navigator.pop(sheetContext, onMenu),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (context.mounted) action?.call();
  }
}
