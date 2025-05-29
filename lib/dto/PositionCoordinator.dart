class PositionCoordinator {
  final int positionCoordinatorId;
  final double positionCoordinatorLatitud;
  final double positionCoordinatorLongitud;
  final int tourSalesId;
  final int coordinatorId;

  PositionCoordinator({
    required this.positionCoordinatorId,
    required this.positionCoordinatorLatitud,
    required this.positionCoordinatorLongitud,
    required this.tourSalesId,
    required this.coordinatorId,
  });

  /// Crea una instancia a partir de un Map (por ejemplo, JSON)
  factory PositionCoordinator.fromJson(Map<String, dynamic> json) {
    return PositionCoordinator(
      positionCoordinatorId: json['position_coordinator_id'] as int,
      positionCoordinatorLatitud:
          (json['position_coordinator_latitud'] as num).toDouble(),
      positionCoordinatorLongitud:
          (json['position_coordinator_longitud'] as num).toDouble(),
      tourSalesId: json['tour_sales_id'] as int,
      coordinatorId: json['coordinator_id'] as int,
    );
  }

  /// Convierte la instancia a Map (útil para enviar JSON)
  Map<String, dynamic> toJson() {
    return {
      'position_coordinator_id': positionCoordinatorId,
      'position_coordinator_latitud': positionCoordinatorLatitud,
      'position_coordinator_longitud': positionCoordinatorLongitud,
      'tour_sales_id': tourSalesId,
      'coordinator_id': coordinatorId,
    };
  }
}
