import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'apple_design_trial.dart';
import 'pilo_family_theme.dart';
import 'pilo_trip_progress.dart';
import 'pilo_family_trip_details.dart';
import 'trip_display_names.dart';
import 'coordinator_home_trial.dart' show homeDestinationCode;
import '../maps/trip_map_data.dart' show parseTripMapDate;

/// PG-031: a bounded home, with the remaining height reserved for the map.
/// Presentation only: passenger identity, permissions and map ownership stay
/// with the existing dashboard and providers.
class FamilyHome extends StatelessWidget {
  const FamilyHome({
    super.key,
    required this.givenNames,
    required this.surnames,
    required this.rut,
    required this.school,
    required this.course,
    required this.year,
    required this.departure,
    required this.returnDate,
    required this.tourCode,
    required this.avatar,
    required this.map,
    required this.onMedical,
    required this.onDiary,
    required this.onCrew,
    required this.onDocuments,
    required this.onMap,
    required this.onGallery,
    this.showNavigation = true,
    this.onMenu,
    this.latestHito,
    this.latestHitoTitle,
    this.latestHitoDate,
    this.galleryPreview,
    this.mapStatus,
    this.onTripDetails,
  });
  final bool showNavigation;
  final VoidCallback? onMenu;
  final Listenable? latestHito;
  final String? Function()? latestHitoTitle;
  final DateTime? Function()? latestHitoDate;
  final Widget? galleryPreview, mapStatus;
  final VoidCallback? onTripDetails;
  final String givenNames, surnames;
  final String rut, school, course, year, departure, returnDate, tourCode;
  final Widget avatar, map;
  final VoidCallback onMedical, onDiary, onCrew, onDocuments, onMap, onGallery;

  String _date(String source) {
    final parsed = parseTripMapDate(source, '');
    return parsed == null
        ? 'Por confirmar'
        : DateFormat('dd/MM/yyyy').format(parsed);
  }

  String get _trip => [
    formatSchoolName(school),
    course.trim(),
    year.trim(),
  ].where((part) => part.isNotEmpty).join(' · ');

  String get _fullName => formatStudentName(givenNames, surnames);
  @override
  Widget build(BuildContext context) =>
      PiloFamilyTheme.isActive(context) ? _piloHome(context) : _originalHome();

  Widget _originalHome() => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context);
      final condensed = bounds.maxHeight < 440 || scale.scale(17) > 25.5;
      final largeText = scale.scale(14) > 21;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, condensed ? 10 : 16, 20, 12),
            child: condensed ? _compactSummary(context) : _summary(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                key: const ValueKey('family-map-card'),
                borderRadius: BorderRadius.circular(20),
                child: ColoredBox(
                  color: AppleTrialColors.background,
                  child: map,
                ),
              ),
            ),
          ),
          if (showNavigation)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Row(
                children: [
                  _action(
                    context,
                    'crew',
                    'Tripulación',
                    CupertinoIcons.bus,
                    Icons.directions_bus_outlined,
                    onCrew,
                    largeText,
                  ),
                  _action(
                    context,
                    'documents',
                    'Documentos',
                    CupertinoIcons.folder,
                    Icons.folder_outlined,
                    onDocuments,
                    largeText,
                  ),
                  _action(
                    context,
                    'diary',
                    'Bitácora',
                    CupertinoIcons.book,
                    Icons.menu_book_outlined,
                    onDiary,
                    largeText,
                  ),
                  _action(
                    context,
                    'map',
                    'Mapa',
                    CupertinoIcons.map,
                    Icons.map_outlined,
                    onMap,
                    largeText,
                  ),
                  _action(
                    context,
                    'gallery',
                    'Galería',
                    CupertinoIcons.photo_on_rectangle,
                    Icons.photo_library_outlined,
                    onGallery,
                    largeText,
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _piloHome(BuildContext context) {
    final studentName = formatStudentName(givenNames, surnames, short: true);
    return LayoutBuilder(
      builder: (context, bounds) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        return SingleChildScrollView(
          key: const ValueKey('pilo-family-home'),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        avatar,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tu estudiante',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Semantics(
                                header: true,
                                child: Text(
                                  studentName.isEmpty
                                      ? 'Estudiante'
                                      : studentName,
                                  style: PiloFamilyTheme.display(
                                    bounds.maxWidth < 350 ? 25 : 29,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onMenu != null) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            key: const ValueKey('family-home-menu'),
                            tooltip: 'Abrir menú',
                            style: IconButton.styleFrom(
                              backgroundColor: PiloFamilyTheme.soft,
                              minimumSize: const Size(44, 44),
                            ),
                            onPressed: onMenu,
                            icon: const Icon(Icons.menu_rounded, size: 23),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PiloTripProgress(
                    departure: departure,
                    returnDate: returnDate,
                    summaryTitle: piloDestinationLabel(tourCode),
                    summarySubtitle: _trip,
                  ),
                  const SizedBox(height: 12),
                  PiloHomeMapCard(
                    key: const ValueKey('family-map-card'),
                    buttonKey: const ValueKey('family-action-map'),
                    compact: true,
                    alignButtonToTop: false,
                    height: largeText ? 190 : 150,
                    status: mapStatus,
                    insetBottom: 12,
                    showOpenArrow: true,
                    map: map,
                    onOpen: onMap,
                  ),
                  const SizedBox(height: 10),
                  if (largeText || bounds.maxWidth < 350) ...[
                    _piloQuickLink(context, medical: false),
                    const SizedBox(height: 8),
                    _piloQuickLink(context, medical: true),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _piloQuickLink(context, medical: false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _piloQuickLink(context, medical: true)),
                      ],
                    ),
                  const SizedBox(height: 10),
                  if (latestHito == null)
                    _piloDiary(context, null)
                  else
                    ListenableBuilder(
                      listenable: latestHito!,
                      builder: (context, _) =>
                          _piloDiary(context, latestHitoTitle?.call()),
                    ),
                  if (galleryPreview != null) ...[
                    const SizedBox(height: 12),
                    galleryPreview!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _piloDiary(BuildContext context, String? latest) {
    final date = latestHitoDate?.call();
    final stamp = date == null
        ? ''
        : ' · ${DateFormat('d MMM', 'es').format(date)} · ${DateFormat('HH:mm').format(date)}';
    return Material(
      key: const ValueKey('family-action-diary'),
      color: PiloFamilyTheme.mint,
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDiary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest == null ? 'Bitácora' : 'Último hito$stamp',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: const Color(0xFF174D43),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest?.trim().isNotEmpty == true
                          ? latest!
                          : 'Novedades de la gira',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const CircleAvatar(
                radius: 21,
                backgroundColor: PiloFamilyTheme.ink,
                foregroundColor: Colors.white,
                child: Icon(Icons.arrow_forward_rounded, size: 23),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _piloQuickLink(BuildContext context, {required bool medical}) =>
      Material(
        key: ValueKey(medical ? 'family-medical' : 'family-trip-details'),
        color: PiloFamilyTheme.soft,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: medical
              ? onMedical
              : onTripDetails ?? () => _showDetails(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
            child: Row(
              children: [
                Icon(
                  medical ? Icons.assignment_add : Icons.work_outline_rounded,
                  color: PiloFamilyTheme.accentText,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medical ? 'Ficha médica' : 'Datos gira',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PiloFamilyTheme.accentText,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    final destination = homeDestinationCode(tourCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: _fullName,
                    child: Text(
                      _fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        height: 1.25,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('family-medical'),
                    onPressed: onMedical,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(48, 44),
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    icon: const Icon(
                      Icons.medical_services_outlined,
                      size: 18,
                      color: Color(0xFF7848AE),
                    ),
                    label: const Text('Ficha médica'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label:
              'Información del viaje: $_trip. Salida: ${_date(departure)}. Regreso: ${_date(returnDate)}${destination == null ? '' : '. Destino: $destination'}',
          child: InkWell(
            key: const ValueKey('family-trip-details'),
            onTap: () => _showDetails(context),
            borderRadius: BorderRadius.circular(12),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _trip,
                    key: const ValueKey('family-trip-title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: AppleTrialColors.secondary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${_date(departure)} → ${_date(returnDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: AppleTrialColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (destination != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppleTrialColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Destino · $destination',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: AppleTrialColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Large text / short landscape: keep a usable map and every action without
  // shrinking type or making the home scroll. Full identity and trip data are
  // available in a scrollable detail sheet opened explicitly by the user.
  Widget _compactSummary(BuildContext context) => Row(
    children: [
      avatar,
      const SizedBox(width: 12),
      Expanded(
        child: TextButton(
          key: const ValueKey('family-compact-details'),
          onPressed: () => _showDetails(context),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            'Tu viaje',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      IconButton(
        key: const ValueKey('family-medical'),
        tooltip: 'Ficha médica',
        onPressed: onMedical,
        icon: const Icon(
          Icons.medical_services_outlined,
          color: Color(0xFF7848AE),
        ),
      ),
    ],
  );

  Widget _action(
    BuildContext context,
    String id,
    String label,
    IconData apple,
    IconData material,
    VoidCallback callback,
    bool iconOnly,
  ) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: ExcludeSemantics(
            child: TextButton(
              key: ValueKey('family-action-$id'),
              onPressed: callback,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 56),
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isApple ? apple : material, size: 24),
                  if (!iconOnly) ...[
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        letterSpacing: -.2,
                        fontWeight: FontWeight.w500,
                        color: AppleTrialColors.ink,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    final destination = homeDestinationCode(tourCode);
    final pilo = PiloFamilyTheme.isActive(context);
    if (pilo) {
      await showPiloFamilyTripDetails(
        context,
        title: piloDestinationLabel(tourCode),
        school: _trip,
        departure: departure,
        returnDate: returnDate,
        onDocuments: onDocuments,
        onCrew: onCrew,
      );
      return;
    }
    final destinationAction = await showModalBottomSheet<VoidCallback>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: pilo ? PiloFamilyTheme.paper : AppleTrialColors.surface,
      shape: pilo
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PiloFamilyTheme.cardRadius),
              ),
            )
          : null,
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fullName, style: Theme.of(context).textTheme.titleLarge),
                if (rut.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('RUT $rut'),
                  ),
                const SizedBox(height: 20),
                Text(_trip, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (destination != null) Text('Destino · $destination'),
                if (pilo) ...[
                  const SizedBox(height: 12),
                  PiloTripDates(
                    departure: _date(departure),
                    returnDate: _date(returnDate),
                  ),
                  const SizedBox(height: 16),
                  PiloHomeAction(
                    key: const ValueKey('family-action-crew'),
                    title: 'Tripulación',
                    leadingIcon: Icons.directions_bus_outlined,
                    color: PiloFamilyTheme.soft,
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () => Navigator.pop(context, onCrew),
                  ),
                  const SizedBox(height: 8),
                  PiloHomeAction(
                    key: const ValueKey('family-action-documents'),
                    title: 'Documentos',
                    leadingIcon: Icons.folder_outlined,
                    color: PiloFamilyTheme.soft,
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () => Navigator.pop(context, onDocuments),
                  ),
                ] else ...[
                  Text('Salida · ${_date(departure)}'),
                  Text('Regreso · ${_date(returnDate)}'),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (context.mounted) destinationAction?.call();
  }
}

String piloDestinationLabel(String tourCode) {
  final destination = homeDestinationCode(tourCode);
  return switch (destination) {
    'BRC' => 'Gira a Bariloche',
    'CMB' => 'Gira a Camboriú',
    'PCN' => 'Gira a Pucón',
    null => 'Tu gira',
    _ => 'Destino · $destination',
  };
}

class PiloHomeMapCard extends StatelessWidget {
  const PiloHomeMapCard({
    super.key,
    this.buttonKey,
    required this.compact,
    required this.alignButtonToTop,
    required this.height,
    required this.map,
    required this.onOpen,
    this.status,
    this.insetBottom = 37,
    this.showOpenArrow = false,
  });

  final Widget? status;
  final double insetBottom;
  final bool showOpenArrow;
  final Key? buttonKey;
  final bool compact;
  final bool alignButtonToTop;
  final double height;
  final Widget map;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(
      compact ? 32 : PiloFamilyTheme.cardRadius + 4,
    ),
    child: ColoredBox(
      color: PiloFamilyTheme.mapBackground,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            map,
            if (status != null)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IgnorePointer(child: status!),
                ),
              ),
            Positioned(
              right: 13,
              bottom: alignButtonToTop ? null : insetBottom,
              top: alignButtonToTop ? 13 : null,
              child: FilledButton(
                key: buttonKey,
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: PiloFamilyTheme.paper,
                  foregroundColor: PiloFamilyTheme.ink,
                  side: const BorderSide(color: PiloFamilyTheme.hairline),
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Abrir mapa'),
                    if (showOpenArrow) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.north_east_rounded, size: 17),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PiloHomeAction extends StatelessWidget {
  const PiloHomeAction({
    super.key,
    required this.title,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.foreground = PiloFamilyTheme.ink,
    this.leadingIcon,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Color color, foreground;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = color == PiloFamilyTheme.ink;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(PiloFamilyTheme.cardRadius),
      ),
    );
    final fullRow = trailing != null;
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: fullRow ? 78 : 72),
          child: Padding(
            padding: EdgeInsets.fromLTRB(fullRow ? 24 : 18, 12, 18, 12),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  ExcludeSemantics(
                    child: Icon(leadingIcon, size: 20, color: foreground),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: foreground),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: dark
                                    ? PiloFamilyTheme.onDark
                                    : const Color(0xFF17332F),
                              ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PiloTripDates extends StatelessWidget {
  const PiloTripDates({
    super.key,
    required this.departure,
    required this.returnDate,
  });

  final String departure;
  final String returnDate;

  @override
  Widget build(BuildContext context) {
    final dateStyle = Theme.of(context).textTheme.bodyMedium;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PiloFamilyTheme.soft,
        borderRadius: BorderRadius.all(Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dateRow(
              'Salida · $departure',
              PiloFamilyTheme.connectorPast,
              dateStyle,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 3.5),
                  child: SizedBox(
                    height: 12,
                    width: 1,
                    child: ColoredBox(color: PiloFamilyTheme.connectorLine),
                  ),
                ),
              ),
            ),
            _dateRow('Regreso · $returnDate', PiloFamilyTheme.ink, dateStyle),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(String label, Color dot, TextStyle? style) => Row(
    children: [
      DecoratedBox(
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: 8),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: style)),
    ],
  );
}
