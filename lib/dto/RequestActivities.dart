class RequestActivities {
  final int activityId;
  final int quantityPassenger;
  final int tourSalesId;

  // Constructor
  RequestActivities({
    required this.activityId,
    required this.quantityPassenger,
    required this.tourSalesId,
  });

  // Método para convertir el objeto a un mapa (para enviar en una solicitud POST)
  Map<String, dynamic> toJson() {
    return {
      'activityId': activityId,
      'quantityPassenger': quantityPassenger,
      'tourSalesId': tourSalesId,
    };
  }

  // Método para crear una instancia de RequestActivities a partir de un mapa (para recibir una respuesta)
  factory RequestActivities.fromJson(Map<String, dynamic> json) {
    return RequestActivities(
      activityId: json['activityId'],
      quantityPassenger: json['quantityPassenger'],
      tourSalesId: json['tourSalesId'],
    );
  }
}
