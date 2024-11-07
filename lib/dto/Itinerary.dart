class Itinerary {
  final String itinerary;

  Itinerary({required this.itinerary});

  // Método para crear una instancia de Itinerary a partir de JSON
  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
      itinerary: json['itinerary'] ??
          '', // Maneja el valor null con un valor por defecto
    );
  }
}
