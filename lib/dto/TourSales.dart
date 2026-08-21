import 'package:papigiras_app/dto/coordinator_session.dart';

class TourSales {
  final int coordinatorId;
  final int tourSalesId;
  final String tourCode;
  final String tourSalesInit;
  final String tourSalesFinal;
  final String nameClient;
  final String courseClient;
  final int seasonClient;
  final String tourTripulationNameId;
  final String tourTripulationIdentificationId;
  final Map<String, int> passengerCountsBySex;
  final String tokenKey;
  final int studentCount;
  final String status;
  final int assignmentId;

  TourSales(
      {required this.coordinatorId,
      required this.tourSalesId,
      required this.tourCode,
      required this.tourSalesInit,
      required this.tourSalesFinal,
      required this.nameClient,
      required this.courseClient,
      required this.seasonClient,
      required this.tourTripulationNameId,
      required this.tourTripulationIdentificationId,
      required this.passengerCountsBySex,
      required this.tokenKey,
      required this.studentCount,
      required this.status,
      required this.assignmentId});

  factory TourSales.fromJson(Map<String, dynamic> json) {
    return TourSales(
        coordinatorId: (json['coordinatorId'] as num?)?.toInt() ?? 0,
        tourSalesId: (json['tourSalesId'] as num).toInt(),
        tourCode: json['tourCode'] ?? '',
        tourSalesInit: json['tourSalesInit'] ?? '',
        tourSalesFinal: json['tourSalesFinal'] ?? '',
        nameClient: json['nameClient'] ?? '',
        courseClient: json['courseClient'] ?? '',
        seasonClient: (json['seasonClient'] as num?)?.toInt() ?? 0,
        tourTripulationNameId: json['tourTripulationNameId'] ?? '',
        tourTripulationIdentificationId:
            json['tourTripulationIdentificationId'] ?? '',
        passengerCountsBySex: _parsePassengerCounts(
          json['passengerCountsBySex'],
        ),
        tokenKey: json['tokenKey'] ?? '',
        studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
        status: json['status'] ?? '',
        assignmentId: (json['assignmentId'] as num?)?.toInt() ?? 0);
  }

  Map<String, dynamic> toJson() {
    return {
      'coordinatorId': coordinatorId,
      'tourSalesId': tourSalesId,
      'tourCode': tourCode,
      'tourSalesInit': tourSalesInit,
      'tourSalesFinal': tourSalesFinal,
      'nameClient': nameClient,
      'courseClient': courseClient,
      'seasonClient': seasonClient,
      'tourTripulationNameId': tourTripulationNameId,
      'tourTripulationIdentificationId': tourTripulationIdentificationId,
      'passengerCountsBySex': passengerCountsBySex,
      'tokenKey': tokenKey,
      'studentCount': studentCount,
      'status': status,
      'assignmentId': assignmentId
    };
  }

  factory TourSales.fromCoordinatorTour({
    required CoordinatorLogin coordinator,
    required CoordinatorTourDetail tour,
  }) {
    return TourSales(
      coordinatorId: coordinator.coordinatorId,
      tourSalesId: tour.tourId,
      tourCode: tour.tourCode,
      tourSalesInit: tour.startDate,
      tourSalesFinal: tour.endDate,
      nameClient: tour.clientName,
      courseClient: tour.course,
      seasonClient: tour.season,
      tourTripulationNameId:
          '${coordinator.name} ${coordinator.lastname}'.trim(),
      tourTripulationIdentificationId: coordinator.rut,
      passengerCountsBySex: tour.passengerCountsBySex,
      tokenKey: coordinator.token,
      studentCount: tour.studentCount,
      status: tour.status,
      assignmentId: tour.assignmentId,
    );
  }
}

Map<String, int> _parsePassengerCounts(dynamic value) {
  if (value is! Map) return const <String, int>{};
  return value.map(
    (key, count) => MapEntry(
      key.toString(),
      count is num ? count.toInt() : int.tryParse(count.toString()) ?? 0,
    ),
  );
}
