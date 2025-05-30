class PassengerList {
  final String? passengerName;
  final int passengerId;
  final String passengerIdentification;
  final bool passengerverificate;
  final String? passengerApellidos;
  final int countMedicalRecordOk;
  final int countMedicalRecordNoOk;
  final String statusMedicalRecord;

  PassengerList({
    required this.passengerName,
    required this.passengerId,
    required this.passengerIdentification,
    required this.passengerverificate,
    required this.passengerApellidos,
    required this.countMedicalRecordOk,
    required this.countMedicalRecordNoOk,
    required this.statusMedicalRecord,
  });

  // Método para crear una instancia de PassengerList desde un JSON
  factory PassengerList.fromJson(Map<String, dynamic> json) {
    return PassengerList(
        passengerName: json['passengerName'],
        passengerId: json['passengerId'],
        passengerIdentification: json['passengerIdentification'],
        passengerverificate: json['passengerverificate'],
        passengerApellidos: json['passengerApellidos'],
        countMedicalRecordOk: json['countMedicalRecordOk'],
        countMedicalRecordNoOk: json['countMedicalRecordNoOk'],
        statusMedicalRecord: json['statusMedicalRecord']);
  }

  // Método para convertir una instancia de PassengerList a JSON
  Map<String, dynamic> toJson() {
    return {
      'passengerName': passengerName,
      'passengerId': passengerId,
      'passengerIdentification': passengerIdentification,
      'passengerverificate': passengerverificate,
      'passengerApellidos': passengerApellidos,
      'countMedicalRecordOk': countMedicalRecordOk,
      'countMedicalRecordNoOk': countMedicalRecordNoOk,
      'statusMedicalRecord': statusMedicalRecord
    };
  }
}
