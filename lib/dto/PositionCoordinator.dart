import 'json_fields.dart';

class PositionCoordinator {
  final int coordinatorId;
  final String coordinatorName;
  final String coordinatorLastname;
  final double latitude;
  final double longitude;
  final DateTime? recordedAt;
  final bool? sharingEnabled;

  PositionCoordinator({
    required this.coordinatorId,
    required this.coordinatorName,
    required this.coordinatorLastname,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.sharingEnabled,
  });

  factory PositionCoordinator.fromJson(Map<String, dynamic> json) {
    return PositionCoordinator(
      coordinatorId: JsonFields.id(json['coordinatorId']),
      coordinatorName: JsonFields.text(json['coordinatorName']),
      coordinatorLastname: JsonFields.text(json['coordinatorLastname']),
      latitude: JsonFields.decimal(json['latitude']),
      longitude: JsonFields.decimal(json['longitude']),
      recordedAt: json['recordedAt'] == null
          ? null
          : DateTime.tryParse(JsonFields.dateText(json['recordedAt'])),
      sharingEnabled: json['sharingEnabled'] is bool
          ? json['sharingEnabled'] as bool
          : null,
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
      if (sharingEnabled != null) 'sharingEnabled': sharingEnabled,
    };
  }

  String get fullName => '$coordinatorName $coordinatorLastname'.trim();
}
