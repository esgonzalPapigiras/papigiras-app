import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'synthetic_location.dart';

/// Visual defaults from flutter_map_location_marker 9.1.1, with a fixed demo
/// synthetic route position and 50m accuracy. No GPS or heading sensor.
class LabLocationMarker extends StatelessWidget {
  const LabLocationMarker({super.key});
  static get position => LabSyntheticLocation.instance.current.latLng;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: LabSyntheticLocation.instance,
    builder: (context, _) => Stack(
      children: [
        CircleLayer(
          circles: [
            CircleMarker(
              point: position,
              radius: 50,
              useRadiusInMeter: true,
              color: const Color(0x182196F3),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: position,
              width: 20,
              height: 20,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF2196F3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
