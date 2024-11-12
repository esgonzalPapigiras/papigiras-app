class DetailHitoList {
  String? titulo;
  String? descripcion;
  String? ubicacion;
  String? notaCierre;
  String? hora;
  List<String>?
      images; // List<byte[]> en Java se convierte en List<List<int>> en Dart

  // Constructor
  DetailHitoList({
    this.titulo,
    this.descripcion,
    this.ubicacion,
    this.notaCierre,
    this.hora,
    this.images,
  });

  // Método para convertir de JSON a objeto Dart
  factory DetailHitoList.fromJson(Map<String, dynamic> json) {
    return DetailHitoList(
      titulo: json['titulo'],
      descripcion: json['descripcion'],
      ubicacion: json['ubicacion'],
      notaCierre: json['notaCierre'],
      hora: json['hora'],
      images: List<String>.from(json['images']),
    );
  }

  // Método para convertir de objeto Dart a JSON
  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'ubicacion': ubicacion,
      'notaCierre': notaCierre,
      'hora': hora,
      'images': images?.map((image) => image).toList(),
    };
  }
}
