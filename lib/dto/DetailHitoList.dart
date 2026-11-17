class DetailHitoList {
  String? titulo;
  String? descripcion;
  String? ubicacion;
  String? notaCierre;
  String? hora;
  List<String>? images;
  List<String>? thumbnails;
  List<int>? photoIds;
  String? fecha;

  DetailHitoList(
      {this.titulo,
      this.descripcion,
      this.ubicacion,
      this.notaCierre,
      this.hora,
      this.images,
      this.thumbnails,
      this.photoIds,
      this.fecha});

  factory DetailHitoList.fromJson(Map<String, dynamic> json) {
    return DetailHitoList(
        titulo: json['titulo'],
        descripcion: json['descripcion'],
        ubicacion: json['ubicacion'],
        notaCierre: json['notaCierre'],
        hora: json['hora'],
        images: List<String>.from(json['images'] ?? const []),
        thumbnails:
            List<String>.from(json['thumbnails'] ?? json['images'] ?? const []),
        photoIds: List<int>.from(
            (json['photoIds'] ?? const []).map((id) => (id as num).toInt())),
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
      'thumbnails': thumbnails?.map((image) => image).toList(),
      'photoIds': photoIds,
      'fecha': fecha
    };
  }
}
