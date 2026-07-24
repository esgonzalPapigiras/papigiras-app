class RequestHito {
  final String titulo;
  final String descripcion;
  final String ubicacion;
  final String notaCierre;
  final String latitud;
  final String longitud;
  final String hora;
  final String fecha;
  final int idTour;

  RequestHito(
      {required this.titulo,
      required this.descripcion,
      required this.ubicacion,
      required this.notaCierre,
      required this.latitud,
      required this.longitud,
      required this.hora,
      required this.idTour,
      required this.fecha});

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'ubicacion': ubicacion,
      'notaCierre': notaCierre,
      'latitud': latitud,
      'longitud': longitud,
      'hora': hora,
      'idTour': idTour,
      'fecha': fecha
    };
  }

  factory RequestHito.fromJson(Map<String, dynamic> json) {
    return RequestHito(
        titulo: json['titulo'],
        descripcion: json['descripcion'],
        ubicacion: json['ubicacion'],
        notaCierre: json['notaCierre'],
        latitud: json['latitud'],
        longitud: json['longitud'],
        hora: json['hora'],
        idTour: json['idTour'],
        fecha: json['fecha']);
  }
}