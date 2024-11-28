class Responseimagepassenger {
  final String image;

  Responseimagepassenger({required this.image});

  // Método para crear una instancia de Itinerary a partir de JSON
  factory Responseimagepassenger.fromJson(Map<String, dynamic> json) {
    return Responseimagepassenger(
        image:
            json['image'] ?? '' // Maneja el valor null con un valor por defecto
        );
  }
}
