class ActivitiesList {
  final String activitiesName;
  final int quantityPassengerCheck;

  ActivitiesList(
      {required this.activitiesName, required this.quantityPassengerCheck});

  // Método para crear una instancia de Itinerary a partir de JSON
  factory ActivitiesList.fromJson(Map<String, dynamic> json) {
    return ActivitiesList(
        activitiesName: json['activitiesName'] ?? '',
        quantityPassengerCheck: json[
            'quantityPassengerCheck'] // Maneja el valor null con un valor por defecto
        );
  }
}
