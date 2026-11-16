import 'package:papigiras_app/lab/mode.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/dto/updateMedicalRecord.dart';

void main() {
  setUp(() => LabMode.useFixturesForTests(true));
  tearDown(() => LabMode.useFixturesForTests(false));
  setUp(LabFixtures.reset);
  test(
    'LAB blocks HTTP client creation before any request can leave the app',
    () {
      final previous = HttpOverrides.current;
      HttpOverrides.global = LabOfflineHttpOverrides();
      try {
        expect(() => HttpClient(), throwsA(isA<SocketException>()));
      } finally {
        HttpOverrides.global = previous;
      }
    },
  );
  test(
    'hito creation is shared only in LAB memory and reset restores fixtures',
    () async {
      final a = CoordinatorProviders(), b = CoordinatorProviders();
      final before = (await a.getBinnacle('1')).length;
      final h = await a.addHito(
        RequestHito(
          titulo: 'Mi prueba',
          descripcion: 'Ficticio',
          ubicacion: 'LAB',
          notaCierre: '',
          latitud: '0',
          longitud: '0',
          hora: '12:00',
          idTour: 1,
          fecha: '10/11/2026',
        ),
      );
      expect((await b.getBinnacle('1')).length, before + 1);
      expect(
        (await b.getHitoComplete(h.binnacleDetailId.toString(), '1')).titulo,
        'Mi prueba',
      );
      await b.deleteHito(h.binnacleDetailId.toString(), '1');
      expect((await a.getBinnacle('1')).length, before);
      LabFixtures.reset();
      expect((await b.getBinnacle('1')).length, before);
    },
  );
  test(
    'medical edits are isolated by synthetic passenger and resettable',
    () async {
      final provider = CoordinatorProviders();
      await provider.sendMedicalDataEdit(
        RequestPassengerMedicalEdit(
          grupoSanguineo: 'A+',
          contactoEmergenciaNombre: 'Contacto ficticio',
          contactoEmergenciaRelacion: 'Demo',
          contactoEmergenciaTelefono: '',
          contactoEmergenciaEmail: 'demo@example.invalid',
          enfermedades: ['Ejemplo editado'],
          medicamentos: [],
          medicamentosEvitar: [],
          idPassenger: 1,
          idTour: 1,
          requiereCuidadosEspeciales: false,
          tieneFonasa: false,
          tieneIsapre: false,
        ),
      );
      expect(
        (await CoordinatorProviders().getMedicalRecord('1', '1')).bloodType,
        'A+',
      );
      expect((await provider.getMedicalRecord('1', '2')).bloodType, 'O+');
      LabFixtures.reset();
      expect((await provider.getMedicalRecord('1', '1')).bloodType, 'O+');
    },
  );
}
