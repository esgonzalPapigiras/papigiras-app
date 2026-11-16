import '../voice/voice_note_metadata.dart';
import 'json_fields.dart';

class HitoAuthor {
  final int coordinatorId;
  final String name;
  final String lastname;

  const HitoAuthor({
    required this.coordinatorId,
    required this.name,
    required this.lastname,
  });

  factory HitoAuthor.fromJson(Map<String, dynamic> json) {
    return HitoAuthor(
      coordinatorId: JsonFields.id(json['coordinatorId']),
      name: JsonFields.text(json['name']),
      lastname: JsonFields.text(json['lastname']),
    );
  }

  String get fullName => '$name $lastname'.trim();
}

class ConsolidatedTourSalesDTO {
  final int binnacleDetailId;
  final String binnacleTitulo;
  final String binnacleDescripcion;
  final String binnacleUbicacion;
  final String binnacleNotaCierre;
  final String binnacleLatitud;
  final String binnacleLongitud;
  final String binnacleHora;
  final String binnacleFecha;
  final HitoAuthor? author;
  final bool canModify;
  final VoiceNoteMetadata? voiceNote;

  ConsolidatedTourSalesDTO({
    required this.binnacleDetailId,
    required this.binnacleTitulo,
    required this.binnacleDescripcion,
    required this.binnacleUbicacion,
    required this.binnacleNotaCierre,
    required this.binnacleLatitud,
    required this.binnacleLongitud,
    required this.binnacleHora,
    required this.binnacleFecha,
    required this.author,
    required this.canModify,
    this.voiceNote,
  });

  factory ConsolidatedTourSalesDTO.fromJson(Map<String, dynamic> json) {
    return ConsolidatedTourSalesDTO(
      binnacleDetailId: JsonFields.id(json['binnacleDetailId']),
      binnacleTitulo: JsonFields.text(json['binnacleTitulo']),
      binnacleDescripcion: JsonFields.text(json['binnacleDescripcion']),
      binnacleUbicacion: JsonFields.text(json['binnacleUbicacion']),
      binnacleNotaCierre: JsonFields.text(json['binnacleNotaCierre']),
      binnacleLatitud: JsonFields.text(json['binnacleLatitud']),
      binnacleLongitud: JsonFields.text(json['binnacleLongitud']),
      binnacleHora: JsonFields.text(json['binnacleHora']),
      binnacleFecha: JsonFields.dateText(
        json['binnacleFecha'] ?? json['binnaclefecha'],
      ),
      author: json['author'] is! Map<String, dynamic>
          ? null
          : HitoAuthor.fromJson(json['author'] as Map<String, dynamic>),
      canModify: JsonFields.boolean(json['canModify']),
      voiceNote: VoiceNoteMetadata.parse(json['voiceNote']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'binnacleDetailId': binnacleDetailId,
      'binnacleTitulo': binnacleTitulo,
      'binnacleDescripcion': binnacleDescripcion,
      'binnacleUbicacion': binnacleUbicacion,
      'binnacleNotaCierre': binnacleNotaCierre,
      'binnacleLatitud': binnacleLatitud,
      'binnacleLongitud': binnacleLongitud,
      'binnacleHora': binnacleHora,
      'binnacleFecha': binnacleFecha,
      'author': author == null
          ? null
          : {
              'coordinatorId': author!.coordinatorId,
              'name': author!.name,
              'lastname': author!.lastname,
            },
      'canModify': canModify,
      'voiceNote': voiceNote?.toJson(),
    };
  }
}
