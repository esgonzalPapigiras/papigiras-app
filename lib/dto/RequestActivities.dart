class RequestActivities {
  final int activityId;
  final int quantityPassenger;
  final int tourSalesId;

  RequestActivities({required this.activityId, required this.quantityPassenger, required this.tourSalesId});

  Map<String, dynamic> toJson() {
    return {'activityId': activityId, 'quantityPassenger': quantityPassenger, 'tourSalesId': tourSalesId};
  }

  factory RequestActivities.fromJson(Map<String, dynamic> json) {
    return RequestActivities(activityId: json['activityId'], quantityPassenger: json['quantityPassenger'], tourSalesId: json['tourSalesId']);
  }
}