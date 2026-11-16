import 'json_fields.dart';

class TourCoordinator {
  final int coordinatorId;
  final String rut;
  final String name;
  final String lastname;
  final String phone;

  const TourCoordinator({
    required this.coordinatorId,
    required this.rut,
    required this.name,
    required this.lastname,
    required this.phone,
  });

  factory TourCoordinator.fromJson(Map<String, dynamic> json) {
    return TourCoordinator(
      coordinatorId: JsonFields.id(json['coordinatorId']),
      rut: JsonFields.text(json['rut']),
      name: JsonFields.text(json['name']),
      lastname: JsonFields.text(json['lastname']),
      phone: JsonFields.text(json['phone']),
    );
  }

  Map<String, dynamic> toJson() => {
    'coordinatorId': coordinatorId,
    'rut': rut,
    'name': name,
    'lastname': lastname,
    'phone': phone,
  };
}

class ResponseAttorney {
  final int? passengerId;
  final String? passengerName;
  final String? passengerApellidos;
  final String? passengerIdentificacion;
  final String? passengerDiet;
  final String? passengerEmail;
  final String? passengerBirthDate;
  final String? passengerGender;
  final int? tourId;
  final String? coordinatorName;
  final String? coordinatorPhone;
  final String? coordinatorIdentificator;
  final String? tourSalesdateInitial;
  final String? tourSalesdateFinal;
  final String? tourSalesUuid;
  final String? tourCourse;
  final String? tourName;
  final int? tourYear;
  final bool? isActive;
  final String? tokenKey;
  final List<TourCoordinator> coordinators;

  ResponseAttorney({
    this.passengerId,
    this.passengerName,
    this.passengerApellidos,
    this.passengerIdentificacion,
    this.passengerDiet,
    this.passengerEmail,
    this.passengerBirthDate,
    this.passengerGender,
    this.tourId,
    this.coordinatorName,
    this.coordinatorPhone,
    this.coordinatorIdentificator,
    this.tourSalesdateInitial,
    this.tourSalesdateFinal,
    this.tourSalesUuid,
    this.tourCourse,
    this.tourName,
    this.tourYear,
    this.isActive,
    this.tokenKey,
    this.coordinators = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerApellidos': passengerApellidos,
      'passengerIdentificacion': passengerIdentificacion,
      'passengerDiet': passengerDiet,
      'passengerEmail': passengerEmail,
      'passengerBirthDate': passengerBirthDate,
      'passengerGender': passengerGender,
      'tourId': tourId,
      'coordinatorName': coordinatorName,
      'coordinatorPhone': coordinatorPhone,
      'coordinatorIdentificator': coordinatorIdentificator,
      'tourSalesdateInitial': tourSalesdateInitial,
      'tourSalesdateFinal': tourSalesdateFinal,
      'tourSalesUuid': tourSalesUuid,
      'tourCourse': tourCourse,
      'tourName': tourName,
      'tourYear': tourYear,
      'isActive': isActive,
      'tokenKey': tokenKey,
      'coordinators': coordinators.map((item) => item.toJson()).toList(),
    };
  }

  factory ResponseAttorney.fromMap(Map<String, dynamic> map) =>
      ResponseAttorney.fromJson(map);

  factory ResponseAttorney.fromJson(Map<String, dynamic> json) {
    return ResponseAttorney(
      passengerId: JsonFields.optionalInt(json['passengerId']),
      passengerName: JsonFields.text(json['passengerName']),
      passengerApellidos: JsonFields.text(json['passengerApellidos']),
      passengerIdentificacion: JsonFields.text(json['passengerIdentificacion']),
      passengerDiet: JsonFields.text(json['passengerDiet']),
      passengerEmail: JsonFields.text(json['passengerEmail']),
      passengerBirthDate: JsonFields.dateText(json['passengerBirthDate']),
      passengerGender: JsonFields.text(json['passengerGender']),
      tourId: JsonFields.optionalInt(json['tourId']),
      coordinatorName: JsonFields.text(json['coordinatorName']),
      coordinatorPhone: JsonFields.text(json['coordinatorPhone']),
      coordinatorIdentificator: JsonFields.text(
        json['coordinatorIdentificator'],
      ),
      tourSalesdateInitial: JsonFields.dateText(json['tourSalesdateInitial']),
      tourSalesdateFinal: JsonFields.dateText(json['tourSalesdateFinal']),
      tourSalesUuid: JsonFields.text(json['tourSalesUuid']),
      tourCourse: JsonFields.text(json['tourCourse']),
      tourName: JsonFields.text(json['tourName']),
      tourYear: JsonFields.optionalInt(json['tourYear']),
      isActive: JsonFields.boolean(json['isActive']),
      tokenKey: JsonFields.text(json['tokenKey']),
      coordinators: JsonFields.records(
        json['coordinators'],
      ).map((item) => TourCoordinator.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerApellidos': passengerApellidos,
      'passengerIdentificacion': passengerIdentificacion,
      'passengerDiet': passengerDiet,
      'passengerEmail': passengerEmail,
      'passengerBirthDate': passengerBirthDate,
      'passengerGender': passengerGender,
      'tourId': tourId,
      'coordinatorName': coordinatorName,
      'coordinatorPhone': coordinatorPhone,
      'coordinatorIdentificator': coordinatorIdentificator,
      'tourSalesdateInitial': tourSalesdateInitial,
      'tourSalesdateFinal': tourSalesdateFinal,
      'tourSalesUuid': tourSalesUuid,
      'tourCourse': tourCourse,
      'tourName': tourName,
      'tourYear': tourYear,
      'isActive': isActive,
      'tokenKey': tokenKey,
      'coordinators': coordinators.map((item) => item.toJson()).toList(),
    };
  }
}
