import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/dto/requestHito.dart';

void main() {
  const enabled = bool.fromEnvironment('LAB_API_INTEGRATION');
  test(
    'local API login, tours, map and persistent hito creation/read/delete',
    () async {
      expect(LabMode.fixturesForTests, isFalse);
      final provider = CoordinatorProviders();
      addTearDown(provider.dispose);
      final coordinator = await provider.loginCoordinator(
        '990000018',
        'PapigirasLAB-2026!',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', coordinator.token);
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      );
      await prefs.setString(
        'coordinatorData',
        jsonEncode(coordinator.toJson()),
      );
      final tours = await provider.getCoordinatorTours();
      expect(tours, isNotEmpty);
      final tour = await provider.getCoordinatorTourDetail(tours.first.tourId);
      expect(tour.tourId, tours.first.tourId);
      final positions = await provider.uniqueID(tour.tourId.toString());
      expect(positions, isNotEmpty);
      final hito = await provider.addHito(
        RequestHito(
          titulo: 'Verificación automática LAB',
          descripcion: 'Contenido ficticio de integración',
          ubicacion: 'LAB',
          notaCierre: '',
          latitud: '-33.4489',
          longitud: '-70.6693',
          hora: '12:00',
          idTour: tour.tourId,
          fecha: '27/10/2026',
        ),
      );
      try {
        final saved = await provider.getHitoComplete(
          hito.binnacleDetailId.toString(),
          tour.tourId.toString(),
        );
        expect(saved.titulo, 'Verificación automática LAB');
      } finally {
        await provider.deleteHito(
          hito.binnacleDetailId.toString(),
          tour.tourId.toString(),
        );
      }
      final passenger = await provider.validateLoginUserPassenger(
        '990000115',
        'PapigirasLAB-2026!',
      );
      expect(passenger?.tokenKey, startsWith('Bearer '));
      final father = await provider.validateLoginUserFather(
        '990000115',
        'PapigirasLAB-2026!',
      );
      expect(father?.tokenKey, startsWith('Bearer '));
    },
    skip: !enabled,
  );
}
