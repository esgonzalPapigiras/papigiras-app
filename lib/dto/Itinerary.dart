import 'json_fields.dart';

class Itinerary {
  final String itinerary;
  final int itineraryId;

  Itinerary({required this.itinerary, required this.itineraryId});

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
      itinerary: JsonFields.text(json['itinerary']),
      itineraryId: JsonFields.id(json['itineraryId']),
    );
  }
}
