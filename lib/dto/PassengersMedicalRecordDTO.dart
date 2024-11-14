class PassengersMedicalRecordDTO {
  final int idPassengersMedicalRecord;
  final String allergiesPassengersRecord;
  final String medicationsPassengersRecord;
  final String medicalPasesengerRecord;
  final int passengerId; // Solo el ID del pasajero
  final int tourSalesId;

  // Constructor
  PassengersMedicalRecordDTO({
    required this.idPassengersMedicalRecord,
    required this.allergiesPassengersRecord,
    required this.medicationsPassengersRecord,
    required this.medicalPasesengerRecord,
    required this.passengerId,
    required this.tourSalesId,
  });

  // Método para convertir de JSON a objeto Dart
  factory PassengersMedicalRecordDTO.fromJson(Map<String, dynamic> json) {
    return PassengersMedicalRecordDTO(
      idPassengersMedicalRecord: json['idPassengersMedicalRecord'],
      allergiesPassengersRecord: json['allergiesPassengersRecord'],
      medicationsPassengersRecord: json['medicationsPassengersRecord'],
      medicalPasesengerRecord: json['medicalPasesengerRecord'],
      passengerId: json['passengerId'],
      tourSalesId: json['tourSalesId'],
    );
  }

  // Método para convertir de objeto Dart a JSON
  Map<String, dynamic> toJson() {
    return {
      'idPassengersMedicalRecord': idPassengersMedicalRecord,
      'allergiesPassengersRecord': allergiesPassengersRecord,
      'medicationsPassengersRecord': medicationsPassengersRecord,
      'medicalPasesengerRecord': medicalPasesengerRecord,
      'passengerId': passengerId,
      'tourSalesId': tourSalesId,
    };
  }
}
