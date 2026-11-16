import 'package:flutter/material.dart';
import '../dto/PassengersMedicalRecordDTO.dart';
import '../dto/responseAttorney.dart';
import '../lab/api_http.dart';
import '../pages/attorney/viewmedicalRecord.dart';
import '../provider/coordinatorProvider.dart';
import 'pilo_family_theme.dart';
import 'trip_display_names.dart';

/// Summary before entering the existing medical form. Only a protected read is
/// made here; no health details or optimistic completion state are cached.
Future<void> showPiloFamilyMedicalPreview(
  BuildContext context, {
  required ResponseAttorney login,
  CoordinatorProviders? provider,
  @visibleForTesting Future<void> Function()? onOpenRecord,
}) async {
  final open = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: PiloFamilyTheme.paper,
    barrierColor: PiloFamilyTheme.ink.withValues(alpha: .34),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) => Theme(
      data: PiloFamilyTheme.theme(Theme.of(context)),
      child: _MedicalPreview(login: login, provider: provider),
    ),
  );
  if (open != true || !context.mounted) return;
  if (onOpenRecord != null) {
    await onOpenRecord();
  } else {
    await ViewMedicalRecordScreen.showSheet(context, login: login);
  }
}

class _MedicalPreview extends StatefulWidget {
  const _MedicalPreview({required this.login, this.provider});
  final ResponseAttorney login;
  final CoordinatorProviders? provider;

  @override
  State<_MedicalPreview> createState() => _MedicalPreviewState();
}

class _MedicalPreviewState extends State<_MedicalPreview> {
  late final _provider = widget.provider ?? CoordinatorProviders();
  PassengersMedicalRecordDTO? _record;
  bool _loading = true;
  bool _missing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _missing = false;
    });
    try {
      if (widget.login.tourId == null || widget.login.passengerId == null) {
        throw StateError('No medical identity');
      }
      final record = await _provider.getMedicalRecord(
        widget.login.tourId.toString(),
        widget.login.passengerId.toString(),
      );
      if (!mounted) return;
      // A malformed success must not be presented as a saved record.
      if (record.idPassengersMedicalRecord == null) {
        throw StateError('No saved medical record');
      }
      setState(() => _record = record);
    } on LabApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _missing = error.statusCode == 404;
        _failed = !_missing;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _savedSubtitle {
    final date = DateTime.tryParse(_record?.authorizationDate ?? '')?.toLocal();
    if (date == null) return 'Disponible para revisar y editar';
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    // This is the actual authorization date, not a claim that the information
    // was recently checked, remains complete, or is medically current.
    return 'Autorizada el ${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = formatStudentName(
      widget.login.passengerName,
      widget.login.passengerApellidos,
      short: true,
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('family-medical-preview'),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PiloFamilyTheme.connectorLine,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Ficha médica',
                        style: PiloFamilyTheme.display(31),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cerrar vista previa de ficha médica',
                    style: IconButton.styleFrom(
                      backgroundColor: PiloFamilyTheme.soft,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _PreviewRow(
                icon: Icons.medical_information_outlined,
                title: name.isEmpty ? 'Estudiante' : name,
                subtitle: 'Ficha del estudiante',
              ),
              const SizedBox(height: 8),
              if (_loading)
                const _PreviewRow(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'Consultando ficha',
                  subtitle: 'Un momento…',
                  loading: true,
                )
              else if (_failed)
                const _PreviewRow(
                  icon: Icons.info_outline_rounded,
                  title: 'No pudimos consultar la ficha',
                  subtitle: 'Intenta nuevamente para ver su estado.',
                )
              else if (_missing)
                const _PreviewRow(
                  icon: Icons.assignment_late_outlined,
                  title: 'Ficha por completar',
                  subtitle: 'Aún no hay una ficha guardada para esta gira.',
                )
              else
                _PreviewRow(
                  icon: Icons.check_rounded,
                  title: 'Ficha guardada',
                  subtitle: _savedSubtitle,
                ),
              const SizedBox(height: 16),
              Text(
                'Antecedentes, cuidados, cobertura de salud y contactos de '
                'emergencia reunidos en un solo lugar.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PiloFamilyTheme.secondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('family-medical-preview-open'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _loading
                    ? null
                    : _failed
                    ? _load
                    : () => Navigator.pop(context, true),
                child: Text(
                  _failed
                      ? 'Reintentar'
                      : _missing
                      ? 'Completar ficha'
                      : 'Ver y editar ficha',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.loading = false,
  });
  final IconData icon;
  final String title, subtitle;
  final bool loading;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 23,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
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
                const SizedBox(height: 5),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
