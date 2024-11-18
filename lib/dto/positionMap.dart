class PositionMap {
  final double latitud;
  final double longitud;

  PositionMap({
    required this.latitud,
    required this.longitud,
  });

  // Método para crear una instancia de Document desde un JSON
  factory PositionMap.fromJson(Map<String, dynamic> json) {
    return PositionMap(
      latitud: json['latitud'],
      longitud: json['longitud'],
    );
  }

  // Método para convertir una instancia de Document a JSON
  Map<String, dynamic> toJson() {
    return {
      'latitud': latitud,
      'longitud': longitud,
    };
  }
}
