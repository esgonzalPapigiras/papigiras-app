class ProgramViewDto {
  String? tourInit;
  String? tourEnd;
  int? countPassenger;
  String? nameClient;
  String? courseClient;
  int? seasonClient;
  List<String>? activities;

  ProgramViewDto({this.tourInit, this.tourEnd, this.countPassenger, this.nameClient, this.courseClient, this.seasonClient, this.activities});

  factory ProgramViewDto.fromJson(Map<String, dynamic> json) {
    return ProgramViewDto(
      tourInit: json['tourInit'],
      tourEnd: json['tourEnd'],
      countPassenger: json['countPassenger'],
      nameClient: json['nameClient'],
      courseClient: json['courseClient'],
      seasonClient: json['seasonClient'],
      activities: List<String>.from(json['activities'] ?? []),
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
      'activities': activities
    };
  }
}
