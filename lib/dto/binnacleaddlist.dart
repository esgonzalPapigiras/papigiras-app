import 'json_fields.dart';

class ActivitiesList {
  final String activitiesName;
  final int quantityPassengerCheck;

  ActivitiesList({
    required this.activitiesName,
    required this.quantityPassengerCheck,
  });

  factory ActivitiesList.fromJson(Map<String, dynamic> json) {
    return ActivitiesList(
      activitiesName: JsonFields.text(json['activitiesName']),
      quantityPassengerCheck: JsonFields.integer(
        json['quantityPassengerCheck'],
      ),
    );
  }
}
