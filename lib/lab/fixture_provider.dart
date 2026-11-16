import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../lab/fixtures.dart';
import '../lab/media.dart';
import '../lab/offline.dart';
import '../dto/coordinator_session.dart';
import '../dto/tourTripulation.dart';
import '../dto/Itinerary.dart';
import '../dto/binnacleaddlist.dart';
import '../dto/RequestActivities.dart';
import '../dto/requestHito.dart';
import '../dto/binnacle.dart';
import '../dto/DetailHitoList.dart';
import '../dto/document.dart';
import '../dto/PassengerList.dart';
import '../dto/responseAttorney.dart';
import '../dto/requestMedicalRecord.dart';
import '../dto/PassengersMedicalRecordDTO.dart';
import '../dto/ProgramViewDto.dart';
import '../dto/positionMap.dart';
import '../dto/PositionCoordinator.dart';
import '../dto/ResponseImagePassenger.dart';
import '../dto/updateMedicalRecord.dart';

/// All operations use synthetic, session-local data. No production implementation
/// or endpoint is present in this project. API shape is retained for original UI.
class FixtureCoordinatorProviders with ChangeNotifier {
  String get token => LabFixtures.token;
  Future<void> checkLoginStatus(BuildContext context) async {}
  Future<CoordinatorLogin> loginCoordinator(
    String rut,
    String password,
  ) async => LabFixtures.coordinator;
  Future<List<CoordinatorTour>> getCoordinatorTours() async => [
    const CoordinatorTour(
      tourId: 1,
      tourCode: 'LAB-2026',
      startDate: '2026-11-10',
      endDate: '2026-11-16',
      status: 'EN_CURSO',
      clientId: 1,
      clientName: 'Colegio Demo',
      course: '3° Medio',
      season: 2026,
      assignmentId: 1,
    ),
  ];
  Future<CoordinatorTourDetail> getCoordinatorTourDetail(int id) async =>
      LabFixtures.tour;
  Future<CoordinatorProfile> getCoordinatorProfile() async =>
      const CoordinatorProfile(
        coordinatorId: 1,
        rut: 'LAB-C01',
        name: 'Coordinador',
        lastname: 'Demo',
        phone: '',
        email: 'coordinador@example.invalid',
        residence: 'Ciudad Demo',
        office: 'Oficina Demo',
        company: 'Agencia Demo',
        hasPicture: false,
      );
  Future<Uint8List?> getCoordinatorPicture() async =>
      LabFixtures.coordinatorPhoto.isEmpty
      ? null
      : base64Decode(LabFixtures.coordinatorPhoto);

  Future<void> updateCoordinatorPicture(XFile image) async {
    LabFixtures.coordinatorPhoto = base64Encode(await image.readAsBytes());
  }

  Future<void> changeCoordinatorPassword(
    String currentPassword,
    String newPassword,
  ) async {
    labNotice('LAB: cambio de contraseña simulado.');
  }

  Future<List<TourTripulation>> getTripulation(String tourCode) async => [
    for (var i = 1; i <= 3; i++)
      TourTripulation(
        tourSalesId: 1,
        tourTripulationIdentificationId: 'LAB-T0$i',
        tourTripulationNameId: i == 1
            ? 'Coordinador Demo'
            : 'Conductor Demo ${i - 1}',
        tourTripulationPhoneId: '',
        tourTripulationDateId: '2026-11-10',
        tourTripulationBusBrand: 'Bus Demo',
        tourTripulationBusPatent: 'LAB-001',
        tourTripulationBusYear: '2026',
        tourTripulationBusModel: 'Modelo de ejemplo',
        tourTripulationBusEnterprise: 'Transportes Demo',
        tourTripulationTypeId: i == 1 ? 32 : i,
      ),
  ];
  Future<List<Itinerary>> getItineray(String code) async => [
    Itinerary(itinerary: 'Caminata de ejemplo', itineraryId: 1),
    Itinerary(itinerary: 'Visita al museo', itineraryId: 2),
    Itinerary(itinerary: 'Actividad en el lago', itineraryId: 3),
  ];
  Future<List<ActivitiesList>> getItinerayGuardados(String code) async =>
      List.of(LabFixtures.activities);
  Future<void> activitiesCreate(RequestActivities request) async {
    final options = await getItineray('1');
    LabFixtures.activities.add(
      ActivitiesList(
        activitiesName: options
            .firstWhere((e) => e.itineraryId == request.activityId)
            .itinerary,
        quantityPassengerCheck: request.quantityPassenger,
      ),
    );
    notifyListeners();
  }

  Future<ConsolidatedTourSalesDTO> addHito(RequestHito r) async {
    final h = ConsolidatedTourSalesDTO(
      binnacleDetailId: LabFixtures.nextHitoId++,
      binnacleTitulo: r.titulo,
      binnacleDescripcion: r.descripcion,
      binnacleUbicacion: r.ubicacion,
      binnacleNotaCierre: r.notaCierre,
      binnacleLatitud: '0',
      binnacleLongitud: '0',
      binnacleHora: r.hora,
      binnacleFecha: r.fecha,
      author: const HitoAuthor(
        coordinatorId: 1,
        name: 'Coordinador',
        lastname: 'Demo',
      ),
      canModify: true,
    );
    LabFixtures.hitos.insert(0, h);
    notifyListeners();
    return h;
  }

  Future<void> addHitoFoto(
    int hito,
    String tourId,
    List<XFile> imageFiles,
  ) async {
    LabFixtures.photos[hito] = [
      for (final f in imageFiles) base64Encode(await f.readAsBytes()),
    ];
  }

  Future<void> deleteHito(String idHito, String idTour) async {
    LabFixtures.hitos.removeWhere(
      (h) => h.binnacleDetailId.toString() == idHito,
    );
    LabFixtures.photos.remove(int.tryParse(idHito));
    notifyListeners();
  }

  Future<DetailHitoList> getHitoComplete(String id, String tour) async {
    final h = LabFixtures.hitos.firstWhere(
      (h) => h.binnacleDetailId.toString() == id,
    );
    return DetailHitoList(
      titulo: h.binnacleTitulo,
      descripcion: h.binnacleDescripcion,
      ubicacion: h.binnacleUbicacion,
      notaCierre: h.binnacleNotaCierre,
      hora: h.binnacleHora,
      fecha: h.binnacleFecha,
      images: LabFixtures.photos[h.binnacleDetailId] ?? [],
    );
  }

  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String code) async =>
      List.of(LabFixtures.hitos);
  Future<List<Document>> getDocument(String code) async => [
    for (final (type, name) in [
      ('Programa gira', 'Programa gira.pdf'),
      ('Póliza de seguro', 'Póliza de seguro.pdf'),
      ('Contrato de gira', 'Contrato de gira.pdf'),
      ('Nomina alumnos', 'Nómina de prueba.pdf'),
    ])
      Document(
        documentName: name,
        documentType: type,
        tourSalesUuid: 'lab-tour-001',
        visibleToAll: true,
      ),
  ];
  Future<List<PassengerList>> getListPassenger(String code) async => [
    for (var i = 1; i <= 8; i++)
      PassengerList(
        passengerName: 'Estudiante $i',
        passengerId: i,
        passengerIdentification: 'LAB-${i.toString().padLeft(3, '0')}',
        passengerverificate: false,
        passengerApellidos: 'Demo',
        countMedicalRecordOk: 1,
        countMedicalRecordNoOk: 0,
        statusMedicalRecord: 'Lleno',
      ),
  ];
  Future<void> downloadDocument(
    String folderName,
    String fileName,
    String idTour,
    String folder,
  ) async {
    labNotice('LAB: descarga simulada; no se solicitaron archivos.');
  }

  Future<void> viewDocument(
    String folderName,
    String fileName,
    String idTour,
    BuildContext context,
    String folder,
  ) async {
    await _showDocument(context, 'Documento de ejemplo');
  }

  Future<void> _showDocument(
    BuildContext context,
    String title,
  ) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: const Text(
        'Papigiras LAB\nColegio Demo · 3° Medio\n10 al 16 de noviembre de 2026\n\nContenido ficticio para probar la interfaz. No hay archivos ni datos reales.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
  Future<ResponseAttorney?> validateLoginUserFather(
    String rut,
    String password,
  ) async => LabFixtures.passenger;
  Future<ResponseAttorney?> validateLoginUserPassenger(
    String rut,
    String password,
  ) async => LabFixtures.passenger;
  Future<bool> validateMedicalRecord(String rut) async => true;
  Future<bool> createMedicalRecord(RequestPassengerMedical record) async {
    LabFixtures.medical[record.idPassenger] = PassengersMedicalRecordDTO(
      idPassengersMedicalRecord: record.idPassenger,
      bloodType: record.grupoSanguineo,
      emergencyContactName: record.contactoEmergenciaNombre,
      emergencyContactRelation: record.contactoEmergenciaRelacion,
      emergencyContactPhone: record.contactoEmergenciaTelefono,
      emergencyContactEmail: record.contactoEmergenciaEmail,
      hasFonasa: record.tieneFonasa,
      hasIsapre: record.tieneIsapre,
      isapre: record.isapre,
      diseases: record.enfermedades,
      medications: record.medicamentos
          .map((e) => e.values.join(' '))
          .join('\n'),
      avoidMedications: record.medicamentosEvitar,
      authorizationDate: '2026-10-26',
      passengerId: record.idPassenger,
      tourSalesId: record.idTour,
      requiresSpecialCare: record.requiereCuidadosEspeciales,
      specialCareDetails: record.cuidadosEspeciales,
    );
    return true;
  }

  Future<PassengersMedicalRecordDTO> getMedicalRecord(
    String tour,
    String passenger,
  ) async {
    final id = int.tryParse(passenger) ?? 1;
    return LabFixtures.medical[id] ?? LabFixtures.defaultMedical(id);
  }

  Future<ProgramViewDto> getviewProgram(String tour) async => ProgramViewDto(
    tourInit: '2026-11-10',
    tourEnd: '2026-11-16',
    countPassenger: 8,
    nameClient: 'Colegio Demo',
    courseClient: '3° Medio',
    seasonClient: 2026,
    activities: [
      'Llegada al destino de prueba',
      'Paseo ficticio por el lago',
      'Visita al museo de ejemplo',
    ],
  );
  Future<void> downloadDocumentMedicalRecord(
    String tour,
    String passenger,
    String id,
  ) async {
    labNotice('LAB: descarga de ficha simulada.');
  }

  Future<void> shareDocumentMedicalRecord(
    String tour,
    String passenger,
    String id,
  ) async {
    labNotice('LAB: compartir ficha está simulado.');
  }

  Future<void> viewDocumentMedicalRecord(
    String tour,
    String passenger,
    BuildContext context,
    String id,
  ) async {
    await _showDocument(context, 'Ficha médica ficticia');
  }

  Future<List<PositionMap>> positionMap(String code) async => [
    PositionMap(latitud: 0, longitud: 0),
  ];
  Future<void> desactivateAccount(String rut) async {
    labNotice('LAB: operación simulada. No existe una cuenta real.');
  }

  Future<void> addHitoFotoPassenger(String id, String tour, XFile file) async {
    LabFixtures.passengerPhoto = base64Encode(await file.readAsBytes());
  }

  Future<Responseimagepassenger> getPicturePassenger(
    String passenger,
    String tour,
  ) async => Responseimagepassenger(image: LabFixtures.passengerPhoto);
  Future<List<PositionCoordinator>> uniqueID(String gps) async => [
    PositionCoordinator(
      coordinatorId: 1,
      coordinatorName: 'Coordinador',
      coordinatorLastname: 'Demo',
      latitude: LabFixtures.busCoordinates[0],
      longitude: LabFixtures.busCoordinates[1],
      recordedAt: LabFixtures.busOnline
          ? DateTime.now().toUtc()
          : LabFixtures.busRecordedAt ?? DateTime.utc(2020, 1, 1),
    ),
  ];
  Future<bool> sendMedicalDataEdit(RequestPassengerMedicalEdit r) async {
    LabFixtures.medical[r.idPassenger] = PassengersMedicalRecordDTO(
      idPassengersMedicalRecord: r.idPassenger,
      bloodType: r.grupoSanguineo,
      emergencyContactName: r.contactoEmergenciaNombre,
      emergencyContactRelation: r.contactoEmergenciaRelacion,
      emergencyContactPhone: r.contactoEmergenciaTelefono,
      emergencyContactEmail: r.contactoEmergenciaEmail,
      hasFonasa: r.tieneFonasa,
      hasIsapre: r.tieneIsapre,
      isapre: r.nombreIsapre,
      diseases: r.enfermedades.join('\n'),
      medications: r.medicamentos.join('\n'),
      avoidMedications: r.medicamentosEvitar.join('\n'),
      authorizationDate: '2026-10-26',
      passengerId: r.idPassenger,
      tourSalesId: r.idTour,
      requiresSpecialCare: r.requiereCuidadosEspeciales,
      specialCareDetails: r.cuidadosEspeciales,
    );
    notifyListeners();
    return true;
  }

  Future<void> updateFcmToken(
    String passengerRut,
    String fcmToken,
    String deviceType,
  ) async {}
}
