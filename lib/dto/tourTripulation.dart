import 'json_fields.dart';

class TourTripulation {
  final int tourSalesId;
  final String tourTripulationIdentificationId;
  final String tourTripulationNameId;
  final String tourTripulationPhoneId;
  final String tourTripulationDateId;
  final String tourTripulationBusBrand;
  final String tourTripulationBusPatent;
  final String tourTripulationBusYear;
  final String tourTripulationBusModel;
  final String tourTripulationBusEnterprise;
  final int tourTripulationTypeId;

  TourTripulation({
    required this.tourSalesId,
    required this.tourTripulationIdentificationId,
    required this.tourTripulationNameId,
    required this.tourTripulationPhoneId,
    required this.tourTripulationDateId,
    required this.tourTripulationBusBrand,
    required this.tourTripulationBusPatent,
    required this.tourTripulationBusYear,
    required this.tourTripulationBusModel,
    required this.tourTripulationBusEnterprise,
    required this.tourTripulationTypeId,
  });

  // Método para convertir un JSON en un objeto TourTripulation
  factory TourTripulation.fromJson(Map<String, dynamic> json) {
    return TourTripulation(
      tourSalesId: JsonFields.id(json['tourSalesId']),
      tourTripulationIdentificationId: JsonFields.text(
        json['tourTripulationIdentificationId'],
      ),
      tourTripulationNameId: JsonFields.text(json['tourTripulationNameId']),
      tourTripulationPhoneId: JsonFields.text(json['tourTripulationPhoneId']),
      tourTripulationDateId: JsonFields.dateText(json['tourTripulationDateId']),
      tourTripulationBusBrand: JsonFields.text(json['tourTripulationBusBrand']),
      tourTripulationBusPatent: JsonFields.text(
        json['tourTripulationBusPatent'],
      ),
      tourTripulationBusYear: JsonFields.text(json['tourTripulationBusYear']),
      tourTripulationBusModel: JsonFields.text(json['tourTripulationBusModel']),
      tourTripulationBusEnterprise: JsonFields.text(
        json['tourTripulationBusEnterprise'],
      ),
      tourTripulationTypeId: JsonFields.integer(json['tourTripulationTypeId']),
    );
  }
}
