class PassengersMedicalRecordDTO {
  final int? idPassengersMedicalRecord;
  final String? bloodType;
  final String? emergencyContactName;
  final String? emergencyContactRelation;
  final String? emergencyContactPhone;
  final String? emergencyContactEmail;
  final bool hasFonasa;
  final bool hasIsapre;
  final String? isapre;
  final String? diseases;
  final String medications;
  final String? avoidMedications;
  final String? authorizationDate;
  final int? passengerId;
  final int? tourSalesId;
  final bool requiresSpecialCare;
  final String? specialCareDetails;

  PassengersMedicalRecordDTO(
      {required this.idPassengersMedicalRecord,
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
      required this.requiresSpecialCare,
      required this.specialCareDetails});

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
      requiresSpecialCare: json['requiereCuidadosEspeciales'] ?? false,
      specialCareDetails: json['cuidadosEspeciales'],
    );
  }

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
      'requiereCuidadosEspeciales': requiresSpecialCare,
      'cuidadosEspeciales': specialCareDetails,
    };
  }
}
