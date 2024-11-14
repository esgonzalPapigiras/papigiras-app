class ProgramViewDto {
  String? tourInit;
  String? tourEnd;
  int? countPassenger;
  String? nameClient;
  String? courseClient;
  int? seasonClient;
  List<String>? activities;

  ProgramViewDto({
    this.tourInit,
    this.tourEnd,
    this.countPassenger,
    this.nameClient,
    this.courseClient,
    this.seasonClient,
    this.activities,
  });

  // Método para convertir un JSON a un objeto ProgramViewDto
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

  // Método para convertir un objeto ProgramViewDto a un JSON
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
