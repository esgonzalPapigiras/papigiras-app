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

  ConsolidatedTourSalesDTO({
    required this.binnacleDetailId,
    required this.binnacleTitulo,
    required this.binnacleDescripcion,
    required this.binnacleUbicacion,
    required this.binnacleNotaCierre,
    required this.binnacleLatitud,
    required this.binnacleLongitud,
    required this.binnacleHora,
    required this.binnacleFecha
  });

  // Método para crear una instancia de ConsolidatedTourSalesDTO desde un JSON
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
      binnacleFecha: json['binnacleFecha'],
    );
  }

  // Método para convertir una instancia de ConsolidatedTourSalesDTO a JSON
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
      'binnacleFecha':binnacleFecha
    };
  }
}
