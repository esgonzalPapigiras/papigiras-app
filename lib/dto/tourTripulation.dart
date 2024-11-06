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
  });

  // Método para convertir un JSON en un objeto TourTripulation
  factory TourTripulation.fromJson(Map<String, dynamic> json) {
    return TourTripulation(
      tourSalesId: json['tourSalesId'],
      tourTripulationIdentificationId: json['tourTripulationIdentificationId'],
      tourTripulationNameId: json['tourTripulationNameId'],
      tourTripulationPhoneId: json['tourTripulationPhoneId'],
      tourTripulationDateId: json['tourTripulationDateId'] ?? '',
      tourTripulationBusBrand: json['tourTripulationBusBrand'],
      tourTripulationBusPatent: json['tourTripulationBusPatent'],
      tourTripulationBusYear: json['tourTripulationBusYear'],
      tourTripulationBusModel: json['tourTripulationBusModel'],
      tourTripulationBusEnterprise: json['tourTripulationBusEnterprise'],
    );
  }
}
