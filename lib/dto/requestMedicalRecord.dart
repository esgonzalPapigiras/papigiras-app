class RequestPassengerMedical {
  String alergias;
  String enfermedades;
  String medicamentos;
  int idPassenger;
  int idTour;

  // Constructor
  RequestPassengerMedical({
    required this.alergias,
    required this.enfermedades,
    required this.medicamentos,
    required this.idPassenger,
    required this.idTour,
  });

  // Métodos para convertir de y a JSON (útil para APIs)
  Map<String, dynamic> toJson() {
    return {
      'alergias': alergias,
      'enfermedades': enfermedades,
      'medicamentos': medicamentos,
      'idPassenger': idPassenger,
      'idTour': idTour,
    };
  }

  // Método para crear un objeto desde un JSON
  factory RequestPassengerMedical.fromJson(Map<String, dynamic> json) {
    return RequestPassengerMedical(
      alergias: json['alergias'] ?? '',
      enfermedades: json['enfermedades'] ?? '',
      medicamentos: json['medicamentos'] ?? '',
      idPassenger: json['idPassenger'] ?? 0,
      idTour: json['idTour'] ?? 0,
    );
  }
}
