import '../dto/responseAttorney.dart';
import '../dto/coordinator_session.dart';
import '../dto/binnacle.dart';
import '../dto/PassengersMedicalRecordDTO.dart';
import '../dto/binnacleaddlist.dart';

class LabFixtures {
  static const mapCoordinates = [[-33.4500, -70.6600], [-33.4268, -70.6345], [-33.4489, -70.6246]];
  static List<double> busCoordinates = mapCoordinates.first;
  static bool busOnline = false;
  static DateTime? busRecordedAt;
  static const token = 'lab-session-not-a-real-token';
  static const coordinator = CoordinatorLogin(coordinatorId: 1, rut: 'LAB-C01', name: 'Coordinador', lastname: 'Demo', mustChangePassword: false, token: token);
  static final passenger = ResponseAttorney(
    passengerId: 1, passengerName: 'Estudiante', passengerApellidos: 'Demo',
    passengerIdentificacion: 'LAB-001', passengerDiet: 'Sin restricciones (ejemplo)',
    passengerEmail: 'estudiante@example.invalid', passengerBirthDate: '2010-05-10', passengerGender: 'F',
    tourId: 1, coordinatorName: 'Coordinador Demo', coordinatorPhone: '', coordinatorIdentificator: 'LAB-C01',
    tourSalesdateInitial: '2026-11-10', tourSalesdateFinal: '2026-11-16', tourSalesUuid: 'lab-tour-001',
    tourCourse: '3° Medio', tourName: 'Colegio Demo', tourYear: 2026, isActive: true, tokenKey: token,
    coordinators: const [TourCoordinator(coordinatorId: 1, rut: 'LAB-C01', name: 'Coordinador', lastname: 'Demo', phone: '')]);
  static const tour = CoordinatorTourDetail(tourId: 1, tourCode: 'LAB-2026', startDate: '2026-11-10', endDate: '2026-11-16', status: 'EN_CURSO', studentCount: 8, clientId: 1, clientName: 'Colegio Demo', course: '3° Medio', season: 2026, branchId: 1, branchName: 'Sucursal Demo', assignmentId: 1, passengerCountsBySex: {'M': 4, 'F': 4, 'AM': 1, 'AF': 1});
  static List<ConsolidatedTourSalesDTO> hitos = _hitos();
  static List<ActivitiesList> activities = [ActivitiesList(activitiesName: 'Caminata de ejemplo', quantityPassengerCheck: 8)];
  static Map<int, PassengersMedicalRecordDTO> medical = {};
  static Map<int, List<String>> photos = {};
  static String passengerPhoto = '';
  static String coordinatorPhoto = '';
  static int nextHitoId = 10;
  static PassengersMedicalRecordDTO defaultMedical(int id) => PassengersMedicalRecordDTO(idPassengersMedicalRecord: id, bloodType: 'O+', emergencyContactName: 'Contacto Demo', emergencyContactRelation: 'Apoderado', emergencyContactPhone: '', emergencyContactEmail: 'contacto@example.invalid', hasFonasa: false, hasIsapre: false, isapre: '', diseases: 'Sin antecedentes (dato ficticio)', medications: 'Ninguno (dato ficticio)', avoidMedications: 'Ninguno', authorizationDate: '2026-10-26', passengerId: id, tourSalesId: 1, requiresSpecialCare: false, specialCareDetails: '');
  static List<ConsolidatedTourSalesDTO> _hitos() => [
    for (final row in [[1, 'Llegada al hotel', 'El grupo llegó al hotel de ejemplo.', '18:30'], [2, 'Paseo por el lago', 'Una actividad ficticia para recorrer la bitácora.', '14:30'], [3, 'Inicio de la gira', 'Todos listos para comenzar el viaje de prueba.', '09:00']])
      ConsolidatedTourSalesDTO(binnacleDetailId: row[0] as int, binnacleTitulo: row[1] as String, binnacleDescripcion: row[2] as String, binnacleUbicacion: 'Destino Demo', binnacleNotaCierre: 'Ejemplo de laboratorio', binnacleLatitud: mapCoordinates[(row[0] as int)-1][0].toString(), binnacleLongitud: mapCoordinates[(row[0] as int)-1][1].toString(), binnacleHora: row[3] as String, binnacleFecha: '10/11/2026', author: const HitoAuthor(coordinatorId: 1, name: 'Coordinador', lastname: 'Demo'), canModify: true)
  ];
  static void reset() {busCoordinates = mapCoordinates.first; busOnline = false; busRecordedAt = null; hitos = _hitos(); activities = [ActivitiesList(activitiesName: 'Caminata de ejemplo', quantityPassengerCheck: 8)]; medical.clear(); photos.clear(); passengerPhoto = ''; coordinatorPhoto = ''; nextHitoId = 10;}
}
