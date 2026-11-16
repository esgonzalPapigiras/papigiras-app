// Vista previa explícita para el simulador. Usa únicamente perfiles ficticios.
// flutter run --no-pub -t test/pilo_apoderado_preview.dart -d <simulador>
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

import 'support/ux_demo_images.dart';

const _tourId = 910001;
const _passengerId = 910011;
const _previewClusters = bool.fromEnvironment('PILO_MAP_CLUSTER_PREVIEW');
const _previewOfflineBus = bool.fromEnvironment('PILO_BUS_OFFLINE_PREVIEW');
final _today = DateTime.now();

String _demoDate(int offset) => DateFormat(
  'yyyy-MM-dd',
).format(DateTime(_today.year, _today.month, _today.day + offset));

final _passenger = ResponseAttorney(
  passengerId: _passengerId,
  passengerName: 'Sofía',
  passengerApellidos: 'Ejemplo LAB',
  passengerIdentificacion: 'LAB-910011',
  tourId: _tourId,
  tourSalesdateInitial: _demoDate(-2),
  tourSalesdateFinal: _demoDate(4),
  tourSalesUuid: 'BRC26910001A',
  tourCourse: '3° Medio B',
  tourName: 'Colegio Horizonte LAB',
  tourYear: _today.year,
  isActive: true,
  tokenKey: LabFixtures.token,
  coordinators: const [
    TourCoordinator(
      coordinatorId: _tourId,
      rut: 'LAB-C910001',
      name: 'Camila',
      lastname: 'Ejemplo LAB',
      phone: '',
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = LabOfflineHttpOverrides();
  SharedPreferences.setMockInitialValues({});
  LabMode.useFixturesForTests(true);
  LabFixtures.reset();
  _seedTrip();
  await LabSession.savePassenger(_passenger, 'attorney');
  runApp(const _PiloApoderadoPreview());
}

void _seedTrip() {
  LabFixtures.busCoordinates = const [-41.0562, -71.5254];
  LabFixtures.busOnline = !_previewOfflineBus;
  if (_previewOfflineBus) {
    LabFixtures.busRecordedAt = _today.subtract(const Duration(minutes: 26));
  } else if (!_previewClusters) {
    Timer(const Duration(seconds: 16), () {
      LabFixtures.busCoordinates = const [-41.0558, -71.5245];
    });
  }
  LabFixtures.hitos = [
    _hito(
      id: 104,
      title: 'Pausa en el mirador',
      description: 'El curso hizo una pausa para mirar el lago.',
      place: 'Mirador del Circuito Chico',
      date: _demoDate(0),
      time: '15:05',
      lat: '-41.059799',
      lon: '-71.5389',
    ),
    _hito(
      id: 103,
      title: 'Una tarde frente al lago',
      description:
          'Recorrimos el sendero del mirador y compartimos una colación frente al Nahuel Huapi.',
      place: 'Mirador del Circuito Chico',
      date: _demoDate(0),
      time: '16:20',
      lat: '-41.0598',
      lon: '-71.5389',
    ),
    _hito(
      id: 102,
      title: 'Caminata entre árboles',
      description:
          'La mañana comenzó con una caminata guiada para conocer el bosque de la zona.',
      place: 'Sendero junto al Lago Moreno',
      date: _demoDate(-1),
      time: '10:10',
      lat: '-41.0692',
      lon: '-71.5201',
    ),
    _hito(
      id: 101,
      title: 'Llegamos a Bariloche',
      description:
          'El grupo llegó a Bariloche y se reunió en el centro para iniciar la gira.',
      place: 'Centro Cívico',
      date: _demoDate(-2),
      time: '15:45',
      lat: '-41.1335',
      lon: '-71.3104',
    ),
  ];
  if (_previewClusters) {
    LabFixtures.busOnline = false;
    LabFixtures.hitos = [
      for (final (baseId, count, latitude, name) in [
        (200, 12, -41.0588, 'Sendero norte'),
        (220, 11, -41.0599, 'Mirador del lago'),
        (240, 12, -41.0610, 'Sendero sur'),
      ])
        for (var index = 0; index < count; index++)
          _hito(
            id: baseId + index,
            title: '$name · Hito ${index + 1}',
            description: 'Registro ficticio para probar el acercamiento.',
            place: name,
            date: _demoDate(0),
            time: '15:${index.toString().padLeft(2, '0')}',
            lat: (latitude + (index ~/ 4) * .00005).toStringAsFixed(5),
            lon: (-71.5389 + (index % 4) * .00005).toStringAsFixed(5),
          ),
    ];
  }
  LabFixtures.photos.addAll({
    101: [uxCityPhoto, uxParkPhoto, uxLagoonPhoto],
    102: [uxParkPhoto, uxLagoonPhoto, uxCityPhoto],
    103: [uxLagoonPhoto, uxParkPhoto, uxCityPhoto],
  });
  LabFixtures.medical[_passengerId] = PassengersMedicalRecordDTO(
    idPassengersMedicalRecord: _passengerId,
    bloodType: 'O+',
    emergencyContactName: 'Contacto Ejemplo LAB',
    emergencyContactRelation: 'Apoderado',
    emergencyContactPhone: '900000000',
    emergencyContactEmail: 'contacto@example.invalid',
    hasFonasa: true,
    hasIsapre: false,
    hasDiseases: false,
    takesMedications: false,
    avoidsMedications: false,
    medicationItems: const [],
    diseases: '',
    medications: '',
    avoidMedications: '',
    authorizationDate: '${_demoDate(-4)}T12:00:00',
    passengerId: _passengerId,
    tourSalesId: _tourId,
    requiresSpecialCare: false,
    specialCareDetails: '',
  );
}

ConsolidatedTourSalesDTO _hito({
  required int id,
  required String title,
  required String description,
  required String place,
  required String date,
  required String time,
  required String lat,
  required String lon,
}) => ConsolidatedTourSalesDTO(
  binnacleDetailId: id,
  binnacleTitulo: title,
  binnacleDescripcion: description,
  binnacleUbicacion: place,
  binnacleNotaCierre: '',
  binnacleLatitud: lat,
  binnacleLongitud: lon,
  binnacleHora: time,
  binnacleFecha: date,
  author: const HitoAuthor(
    coordinatorId: _tourId,
    name: 'Camila',
    lastname: 'Ejemplo LAB',
  ),
  canModify: false,
);

class _PiloApoderadoPreview extends StatelessWidget {
  const _PiloApoderadoPreview();

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => LocationService(),
    child: MaterialApp(
      title: 'PapiGiras LAB · Pilo',
      theme: papiTheme(),
      locale: papiLocale,
      supportedLocales: papiSupportedLocales,
      localizationsDelegates: papiLocalizationsDelegates,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: labMessengerKey,
      home: TravelFatherDashboard(login: _passenger),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: child!,
      ),
    ),
  );
}
