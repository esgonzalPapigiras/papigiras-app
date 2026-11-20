import 'dart:convert';

import 'api_destination.dart';

/// A QR identifies a passenger; it never grants access to their medical data.
/// The counter resolves this ID against its authenticated, selected-tour roster.
class PassengerQrCodec {
  const PassengerQrCodec({required this.destination});

  final ApiDestination? destination;
  static const informationPath = '/app/services/get/information/passenger';
  // Exact origin used by the official a20d994 student QR. Accept its printed
  // codes locally without navigating to (or sending credentials to) that URL.
  static const legacyHost = 'stingray-app-9tqd9.ondigitalocean.app';

  String encode(int passengerId) {
    if (passengerId <= 0) throw ArgumentError.value(passengerId, 'passengerId');
    final url = destination == null
        ? 'papigiras-lab:passenger/$passengerId'
        : destination!.uri(informationPath, {
            'tourPassenger': '$passengerId',
          }).toString();
    return jsonEncode({'id': 20, 'url': url});
  }

  String? decode(String payload) {
    if (payload.length > 2048) return null;
    var value = payload.trim();
    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map || decoded['url'] is! String) return null;
        value = decoded['url'] as String;
      } on FormatException {
        return null;
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasFragment || uri.userInfo.isNotEmpty) return null;
    if (destination == null) {
      if (uri.scheme != 'papigiras-lab' || uri.hasAuthority || uri.hasQuery) {
        return null;
      }
      return RegExp(
        r'^passenger/([1-9][0-9]*)$',
      ).firstMatch(uri.path)?.group(1);
    }
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        (uri.host != destination!.origin.host && uri.host != legacyHost) ||
        uri.path != informationPath) {
      return null;
    }
    final query = uri.queryParametersAll;
    final ids = query['tourPassenger'];
    if (query.length != 1 || ids == null || ids.length != 1) return null;
    return RegExp(r'^[1-9][0-9]*$').hasMatch(ids.single) ? ids.single : null;
  }
}

final passengerQrCodec = PassengerQrCodec(
  destination: AppEnvironment.destination,
);
