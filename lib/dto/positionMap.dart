import 'json_fields.dart';

class PositionMap {
  final double latitud;
  final double longitud;

  PositionMap({required this.latitud, required this.longitud});

  factory PositionMap.fromJson(Map<String, dynamic> json) {
    return PositionMap(
      latitud: JsonFields.decimal(json['latitud']),
      longitud: JsonFields.decimal(json['longitud']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitud': latitud, 'longitud': longitud};
  }
}
