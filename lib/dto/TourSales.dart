import 'json_fields.dart';
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

  TourSales({
    required this.coordinatorId,
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
    required this.assignmentId,
  });

  factory TourSales.fromJson(Map<String, dynamic> json) {
    return TourSales(
      coordinatorId: JsonFields.integer(json['coordinatorId']),
      tourSalesId: JsonFields.id(json['tourSalesId']),
      tourCode: JsonFields.text(json['tourCode']),
      tourSalesInit: JsonFields.dateText(json['tourSalesInit']),
      tourSalesFinal: JsonFields.dateText(json['tourSalesFinal']),
      nameClient: JsonFields.text(json['nameClient']),
      courseClient: JsonFields.text(json['courseClient']),
      seasonClient: JsonFields.integer(json['seasonClient']),
      tourTripulationNameId: JsonFields.text(json['tourTripulationNameId']),
      tourTripulationIdentificationId: JsonFields.text(
        json['tourTripulationIdentificationId'],
      ),
      passengerCountsBySex: _parsePassengerCounts(json['passengerCountsBySex']),
      tokenKey: JsonFields.text(json['tokenKey']),
      studentCount: JsonFields.integer(json['studentCount']),
      status: JsonFields.text(json['status']),
      assignmentId: JsonFields.integer(json['assignmentId']),
    );
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
      'assignmentId': assignmentId,
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
      tourTripulationNameId: '${coordinator.name} ${coordinator.lastname}'
          .trim(),
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
