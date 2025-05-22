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

  // Constructor con parámetros
  ResponseAttorney(
      {this.passengerId,
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
      this.tokenKey});

  // Método para convertir el objeto a un mapa (por ejemplo, para enviar en una solicitud HTTP)
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
      'tokenKey': tokenKey
    };
  }

  // Método para crear un objeto desde un mapa (por ejemplo, para recibir datos de una API)
  factory ResponseAttorney.fromMap(Map<String, dynamic> map) {
    return ResponseAttorney(
        passengerId: map['passengerId'],
        passengerName: map['passengerName'],
        passengerApellidos: map['passengerApellidos'],
        passengerIdentificacion: map['passengerIdentificacion'],
        passengerDiet: map['passengerDiet'],
        passengerEmail: map['passengerEmail'],
        passengerBirthDate: map['passengerBirthDate'],
        passengerGender: map['passengerGender'],
        tourId: map['tourId'],
        coordinatorName: map['coordinatorName'],
        coordinatorPhone: map['coordinatorPhone'],
        coordinatorIdentificator: map['coordinatorIdentificator'],
        tourSalesdateInitial: map['tourSalesdateInitial'],
        tourSalesdateFinal: map['tourSalesdateFinal'],
        tourSalesUuid: map['tourSalesUuid'],
        tourCourse: map['tourCourse'],
        tourName: map['tourName'],
        tourYear: map['tourYear'],
        isActive: map['isActive'],
        tokenKey: map['tokenKey']);
  }

  factory ResponseAttorney.fromJson(Map<String, dynamic> json) {
    return ResponseAttorney(
        passengerId: json['passengerId'],
        passengerName: json['passengerName'],
        passengerApellidos: json['passengerApellidos'],
        passengerIdentificacion: json['passengerIdentificacion'],
        passengerDiet: json['passengerDiet'],
        passengerEmail: json['passengerEmail'],
        passengerBirthDate: json['passengerBirthDate'],
        passengerGender: json['passengerGender'],
        tourId: json['tourId'],
        coordinatorName: json['coordinatorName'],
        coordinatorPhone: json['coordinatorPhone'],
        coordinatorIdentificator: json['coordinatorIdentificator'],
        tourSalesdateInitial: json['tourSalesdateInitial'],
        tourSalesdateFinal: json['tourSalesdateFinal'],
        tourSalesUuid: json['tourSalesUuid'],
        tourCourse: json['tourCourse'],
        tourName: json['tourName'],
        tourYear: json['tourYear'],
        isActive: json['isActive'],
        tokenKey: json['tokenKey']);
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
    };
  }
}
