import 'json_fields.dart';

class PassengerList {
  final String? passengerName;
  final int passengerId;
  final String passengerIdentification;
  final bool passengerverificate;
  final String? passengerApellidos;
  final int countMedicalRecordOk;
  final int countMedicalRecordNoOk;
  final String statusMedicalRecord;
  final String? passengerSex;
  final String? passengerType;
  final String? passengerDiet;

  /// A stored null diet differs from an older API that omits the field.
  final bool hasDietInformation;

  PassengerList({
    required this.passengerName,
    required this.passengerId,
    required this.passengerIdentification,
    required this.passengerverificate,
    required this.passengerApellidos,
    required this.countMedicalRecordOk,
    required this.countMedicalRecordNoOk,
    required this.statusMedicalRecord,
    this.passengerSex,
    this.passengerType,
    this.passengerDiet,
    bool? hasDietInformation,
  }) : hasDietInformation = hasDietInformation ?? passengerDiet != null;

  factory PassengerList.fromJson(Map<String, dynamic> json) {
    return PassengerList(
      passengerName: JsonFields.text(json['passengerName']),
      passengerId: JsonFields.id(json['passengerId']),
      passengerIdentification: JsonFields.text(json['passengerIdentification']),
      passengerverificate: JsonFields.boolean(json['passengerverificate']),
      passengerApellidos: JsonFields.text(json['passengerApellidos']),
      countMedicalRecordOk: JsonFields.integer(json['countMedicalRecordOk']),
      countMedicalRecordNoOk: JsonFields.integer(
        json['countMedicalRecordNoOk'],
      ),
      statusMedicalRecord: JsonFields.text(json['statusMedicalRecord']),
      passengerSex: json['passengerSex'] as String?,
      passengerType: json['passengerType'] as String?,
      passengerDiet: json['passengerDiet'] as String?,
      hasDietInformation: json.containsKey('passengerDiet'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'passengerName': passengerName,
      'passengerId': passengerId,
      'passengerIdentification': passengerIdentification,
      'passengerverificate': passengerverificate,
      'passengerApellidos': passengerApellidos,
      'countMedicalRecordOk': countMedicalRecordOk,
      'countMedicalRecordNoOk': countMedicalRecordNoOk,
      'statusMedicalRecord': statusMedicalRecord,
      'passengerSex': passengerSex,
      'passengerType': passengerType,
      if (hasDietInformation) 'passengerDiet': passengerDiet,
    };
  }
}
