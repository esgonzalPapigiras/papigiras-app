import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../maps/trip_map_data.dart' show parseTripMapDate;
import 'pilo_family_theme.dart';

/// Presentation of the current trip. Navigation remains owned by FamilyJourney.
Future<void> showPiloFamilyTripDetails(
  BuildContext context, {
  required String title,
  required String school,
  required String departure,
  required String returnDate,
  required VoidCallback onDocuments,
  required VoidCallback onCrew,
}) async {
  final start = parseTripMapDate(departure, '00:00');
  final end = parseTripMapDate(returnDate, '00:00');
  final valid = start != null && end != null && !end.isBefore(start);
  String date(DateTime? value) =>
      value == null ? 'Por confirmar' : DateFormat('dd/MM/yyyy').format(value);
  final selected = await showModalBottomSheet<VoidCallback>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: PiloFamilyTheme.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheet) => Theme(
      data: PiloFamilyTheme.theme(Theme.of(sheet)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Datos de la gira',
                        style: PiloFamilyTheme.display(30),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Cerrar datos de la gira',
                      style: IconButton.styleFrom(
                        backgroundColor: PiloFamilyTheme.soft,
                      ),
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _TripRow(
                  icon: Icons.work_outline_rounded,
                  title: title,
                  subtitle: school.isEmpty ? 'Gira asignada' : school,
                ),
                const SizedBox(height: 8),
                _TripRow(
                  icon: Icons.calendar_month_outlined,
                  title: '${date(start)} — ${date(end)}',
                  subtitle: valid
                      ? '${end.difference(start).inDays + 1} días de viaje'
                      : 'Fechas de la gira',
                ),
                const SizedBox(height: 8),
                _TripRow(
                  key: const ValueKey('family-action-documents'),
                  icon: Icons.description_outlined,
                  title: 'Documentos',
                  subtitle: 'Archivos de la gira',
                  onTap: () => Navigator.pop(sheet, onDocuments),
                ),
                const SizedBox(height: 8),
                _TripRow(
                  key: const ValueKey('family-action-crew'),
                  icon: Icons.people_outline_rounded,
                  title: 'Tripulación',
                  subtitle: 'Coordinadores y transporte',
                  onTap: () => Navigator.pop(sheet, onCrew),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (context.mounted) selected?.call();
}

class _TripRow extends StatelessWidget {
  const _TripRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: PiloFamilyTheme.soft,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: PiloFamilyTheme.accentText, size: 25),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: PiloFamilyTheme.accentText,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
