class PassengerList {
  final String? passengerName;
  final int passengerId;
  final String passengerIdentification;
  final bool passengerverificate;

  PassengerList(
      {required this.passengerName,
      required this.passengerId,
      required this.passengerIdentification,
      required this.passengerverificate});

  // Método para crear una instancia de PassengerList desde un JSON
  factory PassengerList.fromJson(Map<String, dynamic> json) {
    return PassengerList(
        passengerName: json['passengerName'],
        passengerId: json['passengerId'],
        passengerIdentification: json['passengerIdentification'],
        passengerverificate: json['passengerverificate']);
  }

  // Método para convertir una instancia de PassengerList a JSON
  Map<String, dynamic> toJson() {
    return {
      'passengerName': passengerName,
      'passengerId': passengerId,
      'passengerIdentification': passengerIdentification,
      'passengerverificate': passengerverificate
    };
  }
}
