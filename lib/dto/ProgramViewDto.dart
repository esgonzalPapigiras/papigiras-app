import 'json_fields.dart';

class ProgramViewDto {
  String tourInit;
  String tourEnd;
  int countPassenger;
  String nameClient;
  String courseClient;
  int seasonClient;
  List<String> activities;

  ProgramViewDto({
    this.tourInit = '',
    this.tourEnd = '',
    this.countPassenger = 0,
    this.nameClient = '',
    this.courseClient = '',
    this.seasonClient = 0,
    this.activities = const [],
  });

  factory ProgramViewDto.fromJson(Map<String, dynamic> json) {
    return ProgramViewDto(
      tourInit: JsonFields.dateText(json['tourInit']),
      tourEnd: JsonFields.dateText(json['tourEnd']),
      countPassenger: JsonFields.integer(json['countPassenger']),
      nameClient: JsonFields.text(json['nameClient']),
      courseClient: JsonFields.text(json['courseClient']),
      seasonClient: JsonFields.integer(json['seasonClient']),
      activities: JsonFields.strings(json['activities']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourInit': tourInit,
      'tourEnd': tourEnd,
      'countPassenger': countPassenger,
      'nameClient': nameClient,
      'courseClient': courseClient,
      'seasonClient': seasonClient,
      'activities': activities,
    };
  }
}
