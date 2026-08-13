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
      coordinatorId: (json['coordinatorId'] as num).toInt(),
      name: json['name'] as String? ?? '',
      lastname: json['lastname'] as String? ?? '',
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

  ConsolidatedTourSalesDTO(
      {required this.binnacleDetailId,
      required this.binnacleTitulo,
      required this.binnacleDescripcion,
      required this.binnacleUbicacion,
      required this.binnacleNotaCierre,
      required this.binnacleLatitud,
      required this.binnacleLongitud,
      required this.binnacleHora,
      required this.binnacleFecha,
      required this.author,
      required this.canModify});

  factory ConsolidatedTourSalesDTO.fromJson(Map<String, dynamic> json) {
    return ConsolidatedTourSalesDTO(
      binnacleDetailId: json['binnacleDetailId'],
      binnacleTitulo: json['binnacleTitulo'],
      binnacleDescripcion: json['binnacleDescripcion'],
      binnacleUbicacion: json['binnacleUbicacion'],
      binnacleNotaCierre: json['binnacleNotaCierre'],
      binnacleLatitud: json['binnacleLatitud'],
      binnacleLongitud: json['binnacleLongitud'],
      binnacleHora: json['binnacleHora'],
      binnacleFecha: json['binnacleFecha'] ?? json['binnaclefecha'] ?? '',
      author: json['author'] == null
          ? null
          : HitoAuthor.fromJson(json['author'] as Map<String, dynamic>),
      canModify: json['canModify'] as bool? ?? false,
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
      'canModify': canModify
    };
  }
}
