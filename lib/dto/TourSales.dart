class TourSales {
  final int tourSalesId;
  final String tourSalesInit;
  final String tourSalesFinal;
  final String nameClient;
  final String courseClient;
  final int seasonClient;
  final String tourTripulationNameId;
  final String tourTripulationIdentificationId;
  final Map<String, int> passengerCountsBySex;

  TourSales({
    required this.tourSalesId,
    required this.tourSalesInit,
    required this.tourSalesFinal,
    required this.nameClient,
    required this.courseClient,
    required this.seasonClient,
    required this.tourTripulationNameId,
    required this.tourTripulationIdentificationId,
    required this.passengerCountsBySex,
  });

  // Método para crear una instancia de TourSales desde un JSON
  factory TourSales.fromJson(Map<String, dynamic> json) {
    return TourSales(
      tourSalesId: json['tourSalesId'],
      tourSalesInit: json['tourSalesInit'],
      tourSalesFinal: json['tourSalesFinal'],
      nameClient: json['nameClient'],
      courseClient: json['courseClient'],
      seasonClient: json['seasonClient'],
      tourTripulationNameId: json['tourTripulationNameId'],
      tourTripulationIdentificationId: json['tourTripulationIdentificationId'],
      passengerCountsBySex: Map<String, int>.from(json['passengerCountsBySex']),
    );
  }

  // Método para convertir una instancia de TourSales a JSON
  Map<String, dynamic> toJson() {
    return {
      'tourSalesId': tourSalesId,
      'tourSalesInit': tourSalesInit,
      'tourSalesFinal': tourSalesFinal,
      'nameClient': nameClient,
      'courseClient': courseClient,
      'seasonClient': seasonClient,
      'tourTripulationNameId': tourTripulationNameId,
      'tourTripulationIdentificationId': tourTripulationIdentificationId,
      'passengerCountsBySex': passengerCountsBySex,
    };
  }
}
