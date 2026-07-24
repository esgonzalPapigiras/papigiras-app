class DetailHitoList {
  String? titulo;
  String? descripcion;
  String? ubicacion;
  String? notaCierre;
  String? hora;
  List<String>? images;
  String? fecha;

  DetailHitoList({this.titulo, this.descripcion, this.ubicacion, this.notaCierre, this.hora, this.images, this.fecha});

  factory DetailHitoList.fromJson(Map<String, dynamic> json) {
    return DetailHitoList(
        titulo: json['titulo'],
        descripcion: json['descripcion'],
        ubicacion: json['ubicacion'],
        notaCierre: json['notaCierre'],
        hora: json['hora'],
        images: List<String>.from(json['images']),
        fecha: json['fecha']);
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'ubicacion': ubicacion,
      'notaCierre': notaCierre,
      'hora': hora,
      'images': images?.map((image) => image).toList(),
      'fecha': fecha
    };
  }
}
