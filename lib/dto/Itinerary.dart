class Itinerary {
  final String itinerary;
  final int itineraryId;

  Itinerary({required this.itinerary, required this.itineraryId});

  // Método para crear una instancia de Itinerary a partir de JSON
  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
        itinerary: json['itinerary'] ?? '',
        itineraryId:
            json['itineraryId'] // Maneja el valor null con un valor por defecto
        );
  }
}
