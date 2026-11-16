import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/LocationService.dart';
import 'synthetic_location.dart';

class LabLocationControls extends StatelessWidget {
  const LabLocationControls({super.key});
  @override
  Widget build(BuildContext context) {
    final service = context.watch<LocationService>();
    return AnimatedBuilder(
      animation: service.source,
      builder: (context, _) {
        final source = service.source;
        return AlertDialog(
          title: const Text('Recorrido ficticio LAB'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No usa la ubicación de tu Mac ni del teléfono. Si compartir está activo, envía puntos de prueba al servidor local y avanza cada minuto con la app abierta.',
                ),
                const SizedBox(height: 12),
                Text(source.current.address),
                Text('${source.current.latitude}, ${source.current.longitude}'),
                Slider(
                  value: source.index.toDouble(),
                  min: 0,
                  max: (LabSyntheticLocation.route.length - 1).toDouble(),
                  divisions: LabSyntheticLocation.route.length - 1,
                  label: 'Parada ${source.index + 1}',
                  onChanged: (value) =>
                      service.selectSyntheticPoint(value.round()),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avance automático'),
                  value: !source.paused,
                  onChanged: (value) => source.setPaused(!value),
                ),
                Text(
                  service.isTracking
                      ? 'Envío local activo · ${service.pendingCount} pendientes'
                      : 'Envío local desactivado. Actívalo en el inicio del coordinador.',
                ),
                if (service.lastError != null)
                  Text(
                    service.lastError!,
                    style: const TextStyle(color: Colors.orange),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Solo funciona con la app abierta. Al volver, reanuda los envíos y reintentos únicamente si compartir sigue activo.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => service.selectSyntheticPoint(
                (source.index + 1) % LabSyntheticLocation.route.length,
              ),
              child: const Text('Siguiente punto'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}
