class PassengersMedicalRecordDTO {
  final int idPassengersMedicalRecord;
  final String bloodType; // grupoSanguineo
  final String emergencyContactName; // contactoEmergenciaNombre
  final String emergencyContactRelation; // contactoEmergenciaRelacion
  final String emergencyContactPhone; // contactoEmergenciaTelefono
  final String emergencyContactEmail; // contactoEmergenciaEmail
  final bool hasFonasa; // tieneFonasa
  final bool hasIsapre; // tieneIsapre
  final String? isapre; // isapre
  final String diseases; // enfermedades
  final String medications; // medicamentos
  final String avoidMedications; // medicamentosEvitar
  final String authorizationDate; // fechaAutorizacion
  final int passengerId; // Solo el ID del pasajero
  final int tourSalesId;

  // Constructor
  PassengersMedicalRecordDTO({
    required this.idPassengersMedicalRecord,
    required this.bloodType,
    required this.emergencyContactName,
    required this.emergencyContactRelation,
    required this.emergencyContactPhone,
    required this.emergencyContactEmail,
    required this.hasFonasa,
    required this.hasIsapre,
    this.isapre,
    required this.diseases,
    required this.medications,
    required this.avoidMedications,
    required this.authorizationDate,
    required this.passengerId,
    required this.tourSalesId,
  });

  // Método para convertir de JSON a objeto Dart
  factory PassengersMedicalRecordDTO.fromJson(Map<String, dynamic> json) {
    return PassengersMedicalRecordDTO(
      idPassengersMedicalRecord: json['idPassengersMedicalRecord'],
      bloodType: json['grupoSanguineo'],
      emergencyContactName: json['contactoEmergenciaNombre'],
      emergencyContactRelation: json['contactoEmergenciaRelacion'],
      emergencyContactPhone: json['contactoEmergenciaTelefono'],
      emergencyContactEmail: json['contactoEmergenciaEmail'],
      hasFonasa: json['tieneFonasa'],
      hasIsapre: json['tieneIsapre'],
      isapre: json['isapre'],
      diseases: json['enfermedades'],
      medications: json['medicamentos'],
      avoidMedications: json['medicamentosEvitar'],
      authorizationDate: json['fechaAutorizacion'],
      passengerId: json['passengerId'],
      tourSalesId: json['tourSalesId'],
    );
  }

  // Método para convertir de objeto Dart a JSON
  Map<String, dynamic> toJson() {
    return {
      'idPassengersMedicalRecord': idPassengersMedicalRecord,
      'bloodType': bloodType,
      'emergencyContactName': emergencyContactName,
      'emergencyContactRelation': emergencyContactRelation,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactEmail': emergencyContactEmail,
      'hasFonasa': hasFonasa,
      'hasIsapre': hasIsapre,
      'isapre': isapre,
      'diseases': diseases,
      'medications': medications,
      'avoidMedications': avoidMedications,
      'authorizationDate': authorizationDate,
      'passengerId': passengerId,
      'tourSalesId': tourSalesId,
    };
  }
}
