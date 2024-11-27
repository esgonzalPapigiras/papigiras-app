class RequestHito {
  final String titulo;
  final String descripcion;
  final String ubicacion;
  final String notaCierre;
  final String latitud;
  final String longitud;
  final String hora;
  final String fecha;
  final int idTour; // En Dart usamos `int` para números enteros.

  // Constructor
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

  // Método para convertir el objeto a un mapa (para enviar en una solicitud POST)
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

  // Método para crear una instancia de RequestHito a partir de un mapa (para recibir una respuesta)
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
