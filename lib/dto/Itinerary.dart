class Itinerary {
  final String itineraryName;

  Itinerary({required this.itineraryName});

  // Método para convertir un JSON en un objeto Itinerary
  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
      itineraryName: json[
          'itinerary_name'], // Asegúrate de que la clave coincida con la respuesta de tu API
    );
  }
}
