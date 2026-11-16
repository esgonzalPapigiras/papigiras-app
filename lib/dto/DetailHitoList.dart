import '../voice/voice_note_metadata.dart';
import '../lab/media_data.dart';
import 'json_fields.dart';

class DetailHitoList {
  String? titulo;
  String? descripcion;
  String? ubicacion;
  String? notaCierre;
  String? hora;
  List<String> images;

  /// Persistent photo identities, aligned with the decoded images.
  List<int?> imageIds;
  int missingImageCount;
  String? fecha;
  VoiceNoteMetadata? voiceNote;

  DetailHitoList({
    this.titulo,
    this.descripcion,
    this.ubicacion,
    this.notaCierre,
    this.hora,
    this.images = const [],
    this.imageIds = const [],
    this.missingImageCount = 0,
    this.fecha,
    this.voiceNote,
  });

  factory DetailHitoList.fromJson(Map<String, dynamic> json) {
    final images = <String>[];
    final imageIds = <int?>[];
    final rawImages = json['images'] is List
        ? json['images'] as List
        : const [];
    final rawIds = json['imageIds'] is List
        ? json['imageIds'] as List
        : const [];
    for (var index = 0; index < rawImages.length; index++) {
      final image = rawImages[index];
      if (image is! String || LocalImageData.decode(image) == null) continue;
      images.add(image);
      final id = index < rawIds.length ? JsonFields.integer(rawIds[index]) : 0;
      imageIds.add(id > 0 ? id : null);
    }
    return DetailHitoList(
      titulo: JsonFields.text(json['titulo']),
      descripcion: JsonFields.text(json['descripcion']),
      ubicacion: JsonFields.text(json['ubicacion']),
      notaCierre: JsonFields.text(json['notaCierre']),
      hora: JsonFields.text(json['hora']),
      images: images,
      imageIds: imageIds,
      fecha: JsonFields.dateText(json['fecha']),
      voiceNote: VoiceNoteMetadata.parse(json['voiceNote']),
      missingImageCount: JsonFields.integer(
        json['missingImageCount'],
      ).clamp(0, 2147483647),
    );
  }

  int? photoIdAt(int index) =>
      index >= 0 && index < imageIds.length ? imageIds[index] : null;

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'ubicacion': ubicacion,
      'notaCierre': notaCierre,
      'hora': hora,
      'images': images,
      'imageIds': imageIds,
      'missingImageCount': missingImageCount,
      'fecha': fecha,
      'voiceNote': voiceNote?.toJson(),
    };
  }
}
