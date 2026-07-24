class PositionMap {
  final double latitud;
  final double longitud;

  PositionMap({required this.latitud, required this.longitud});

  factory PositionMap.fromJson(Map<String, dynamic> json) {
    return PositionMap(latitud: json['latitud'], longitud: json['longitud']);
  }

  Map<String, dynamic> toJson() {
    return {'latitud': latitud, 'longitud': longitud};
  }
}
