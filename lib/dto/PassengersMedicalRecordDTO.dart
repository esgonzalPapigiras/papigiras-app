import 'json_fields.dart';

class PassengersMedicalRecordDTO {
  final int? idPassengersMedicalRecord;
  final String? bloodType;
  final bool? hasDiseases;
  final bool? takesMedications;
  final bool? avoidsMedications;
  final List<Map<String, String>>? medicationItems;
  final String? revision;
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

  PassengersMedicalRecordDTO({
    required this.idPassengersMedicalRecord,
    required this.bloodType,
    this.hasDiseases,
    this.takesMedications,
    this.avoidsMedications,
    this.medicationItems,
    this.revision,
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
    required this.specialCareDetails,
  });

  factory PassengersMedicalRecordDTO.fromJson(Map<String, dynamic> json) {
    return PassengersMedicalRecordDTO(
      idPassengersMedicalRecord: JsonFields.optionalInt(
        json['idPassengersMedicalRecord'],
      ),
      bloodType: JsonFields.text(json['grupoSanguineo']),
      hasDiseases: json['tieneEnfermedades'] is bool
          ? json['tieneEnfermedades']
          : null,
      takesMedications: json['tomaMedicamentos'] is bool
          ? json['tomaMedicamentos']
          : null,
      avoidsMedications: json['evitarMedicamentos'] is bool
          ? json['evitarMedicamentos']
          : null,
      medicationItems: json['medicamentosDetalle'] is List
          ? (json['medicamentosDetalle'] as List)
                .map((item) => Map<String, String>.from(item as Map))
                .toList()
          : null,
      revision: json['revision'] as String?,
      emergencyContactName: JsonFields.text(json['contactoEmergenciaNombre']),
      emergencyContactRelation: JsonFields.text(
        json['contactoEmergenciaRelacion'],
      ),
      emergencyContactPhone: JsonFields.text(
        json['contactoEmergenciaTelefono'],
      ),
      emergencyContactEmail: JsonFields.text(json['contactoEmergenciaEmail']),
      hasFonasa: JsonFields.boolean(json['tieneFonasa']),
      hasIsapre: JsonFields.boolean(json['tieneIsapre']),
      isapre: JsonFields.text(json['isapre']),
      diseases: JsonFields.text(json['enfermedades']),
      medications: JsonFields.text(json['medicamentos']),
      avoidMedications: JsonFields.text(json['medicamentosEvitar']),
      authorizationDate: JsonFields.dateText(json['fechaAutorizacion']),
      passengerId: JsonFields.optionalInt(json['passengerId']),
      tourSalesId: JsonFields.optionalInt(json['tourSalesId']),
      requiresSpecialCare: JsonFields.boolean(
        json['requiereCuidadosEspeciales'],
      ),
      specialCareDetails: JsonFields.text(json['cuidadosEspeciales']),
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
