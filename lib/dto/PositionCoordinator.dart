class PositionCoordinator {
  final int coordinatorId;
  final String coordinatorName;
  final String coordinatorLastname;
  final double latitude;
  final double longitude;
  final DateTime? recordedAt;

  PositionCoordinator({
    required this.coordinatorId,
    required this.coordinatorName,
    required this.coordinatorLastname,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  factory PositionCoordinator.fromJson(Map<String, dynamic> json) {
    return PositionCoordinator(
      coordinatorId: (json['coordinatorId'] as num).toInt(),
      coordinatorName: json['coordinatorName'] as String? ?? '',
      coordinatorLastname: json['coordinatorLastname'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: json['recordedAt'] == null
          ? null
          : DateTime.tryParse(json['recordedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coordinatorId': coordinatorId,
      'coordinatorName': coordinatorName,
      'coordinatorLastname': coordinatorLastname,
      'latitude': latitude,
      'longitude': longitude,
      'recordedAt': recordedAt?.toIso8601String(),
    };
  }

  String get fullName => '$coordinatorName $coordinatorLastname'.trim();
}
