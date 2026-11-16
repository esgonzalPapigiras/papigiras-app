import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/utils/LocationService.dart';

/// Coordinator sharing control. The LAB service only emits synthetic positions.
class CoordinatorLocationToggle extends StatelessWidget {
  const CoordinatorLocationToggle({super.key, this.compact = false});

  final bool compact;

  Future<void> _change(
    BuildContext context,
    LocationService service,
    bool enabled,
  ) async {
    if (service.isChangingMode) return;
    try {
      await service.setSharingEnabled(enabled);
      if (!context.mounted) return;
      final error = service.lastError;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cambiar la ubicación de prueba. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LocationService>();
    final pilo = PiloFamilyTheme.isActive(context);
    final onTrack = pilo ? PiloFamilyTheme.mint : const Color(0xFF16A36A);
    final offTrack = pilo ? PiloFamilyTheme.hairline : const Color(0xFFE4E7E7);
    if (compact && pilo) {
      final onTap = service.isChangingMode
          ? null
          : () => _change(context, service, !service.isTracking);
      return Semantics(
        label: 'Compartir ubicación de prueba',
        toggled: service.isTracking,
        enabled: !service.isChangingMode,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('coordinator-map-location-toggle'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: const ShapeDecoration(
                    color: PiloFamilyTheme.paper,
                    shape: StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 22,
                        child: service.isChangingMode
                            ? const Padding(
                                padding: EdgeInsets.all(3),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PiloFamilyTheme.accentText,
                                ),
                              )
                            : IgnorePointer(
                                child: FittedBox(
                                  child: Switch(
                                    value: service.isTracking,
                                    onChanged: (value) =>
                                        _change(context, service, value),
                                    thumbColor: const WidgetStatePropertyAll(
                                      PiloFamilyTheme.ink,
                                    ),
                                    trackColor: WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                          ? onTrack
                                          : offTrack,
                                    ),
                                    trackOutlineColor:
                                        const WidgetStatePropertyAll(
                                          Colors.transparent,
                                        ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ubicación',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.2,
                          color: PiloFamilyTheme.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return MergeSemantics(
      child: Semantics(
        label: 'Compartir ubicación de prueba',
        child: Tooltip(
          message: service.isTracking
              ? 'Ubicación de prueba activada · recorrido ficticio'
              : 'Activar ubicación de prueba · recorrido ficticio',
          excludeFromSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pilo)
                  Flexible(
                    child: GestureDetector(
                      onTap: service.isChangingMode
                          ? null
                          : () =>
                                _change(context, service, !service.isTracking),
                      behavior: HitTestBehavior.opaque,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Compartir ubicación',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              service.isChangingMode
                                  ? 'Actualizando…'
                                  : service.isTracking
                                  ? 'Compartiendo'
                                  : 'Desactivada',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                height: 1.4,
                                color: service.isTracking
                                    ? PiloFamilyTheme.accentText
                                    : PiloFamilyTheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ExcludeSemantics(
                    child: Icon(
                      Icons.location_on_rounded,
                      color: pilo
                          ? PiloFamilyTheme.accentText
                          : const Color(0xFFF4C542),
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 60,
                  child: Switch(
                    value: service.isTracking,
                    onChanged: service.isChangingMode
                        ? null
                        : (value) => _change(context, service, value),
                    thumbColor: WidgetStatePropertyAll(
                      pilo ? PiloFamilyTheme.ink : Colors.white,
                    ),
                    trackColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? onTrack
                          : offTrack,
                    ),
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
