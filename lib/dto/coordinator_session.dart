import 'json_fields.dart';

class CoordinatorLogin {
  final int coordinatorId;
  final String rut;
  final String name;
  final String lastname;
  final bool mustChangePassword;
  final String token;

  const CoordinatorLogin({
    required this.coordinatorId,
    required this.rut,
    required this.name,
    required this.lastname,
    required this.mustChangePassword,
    required this.token,
  });

  factory CoordinatorLogin.fromJson(Map<String, dynamic> json) {
    return CoordinatorLogin(
      coordinatorId: JsonFields.id(json['coordinatorId']),
      rut: JsonFields.text(json['rut']),
      name: JsonFields.text(json['name']),
      lastname: JsonFields.text(json['lastname']),
      mustChangePassword: JsonFields.boolean(json['mustChangePassword']),
      token: JsonFields.text(json['token']),
    );
  }

  Map<String, dynamic> toJson() => {
    'coordinatorId': coordinatorId,
    'rut': rut,
    'name': name,
    'lastname': lastname,
    'mustChangePassword': mustChangePassword,
    'token': token,
  };
}

class CoordinatorTour {
  final int tourId;
  final String tourCode;
  final String startDate;
  final String endDate;
  final String status;
  final int clientId;
  final String clientName;
  final String course;
  final int season;
  final int assignmentId;

  const CoordinatorTour({
    required this.tourId,
    required this.tourCode,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.clientId,
    required this.clientName,
    required this.course,
    required this.season,
    required this.assignmentId,
  });

  factory CoordinatorTour.fromJson(Map<String, dynamic> json) {
    return CoordinatorTour(
      tourId: JsonFields.id(json['tourId']),
      tourCode: JsonFields.text(json['tourCode']),
      startDate: JsonFields.dateText(json['startDate']),
      endDate: JsonFields.dateText(json['endDate']),
      status: JsonFields.text(json['status']),
      clientId: JsonFields.integer(json['clientId']),
      clientName: JsonFields.text(json['clientName']),
      course: JsonFields.text(json['course']),
      season: JsonFields.integer(json['season']),
      assignmentId: JsonFields.id(json['assignmentId']),
    );
  }
}

class CoordinatorTourDetail {
  final int tourId;
  final String tourCode;
  final String startDate;
  final String endDate;
  final String status;
  final int studentCount;
  final int clientId;
  final String clientName;
  final String course;
  final int season;
  final int branchId;
  final String branchName;
  final int assignmentId;
  final Map<String, int> passengerCountsBySex;

  /// Null means the server did not supply a valid count; {} is a real zero.
  final Map<String, int>? specialDietCounts;

  const CoordinatorTourDetail({
    required this.tourId,
    required this.tourCode,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.studentCount,
    required this.clientId,
    required this.clientName,
    required this.course,
    required this.season,
    required this.branchId,
    required this.branchName,
    required this.assignmentId,
    required this.passengerCountsBySex,
    this.specialDietCounts,
  });

  factory CoordinatorTourDetail.fromJson(Map<String, dynamic> json) {
    return CoordinatorTourDetail(
      tourId: JsonFields.id(json['tourId']),
      tourCode: JsonFields.text(json['tourCode']),
      startDate: JsonFields.dateText(json['startDate']),
      endDate: JsonFields.dateText(json['endDate']),
      status: JsonFields.text(json['status']),
      studentCount: JsonFields.integer(json['studentCount']),
      clientId: JsonFields.integer(json['clientId']),
      clientName: JsonFields.text(json['clientName']),
      course: JsonFields.text(json['course']),
      season: JsonFields.integer(json['season']),
      branchId: JsonFields.integer(json['branchId']),
      branchName: JsonFields.text(json['branchName']),
      assignmentId: JsonFields.id(json['assignmentId']),
      passengerCountsBySex: _parsePassengerCounts(json['passengerCountsBySex']),
      specialDietCounts: _parseSpecialDietCounts(json['specialDietCounts']),
    );
  }
}

Map<String, int>? _parseSpecialDietCounts(dynamic value) {
  if (value is! Map) return null;
  final result = <String, int>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final count = JsonFields.optionalInt(entry.value);
    if (key is! String || key.trim().isEmpty || count == null || count < 0) {
      return null; // Never turn an unavailable/invalid summary into zero.
    }
    result[key] = count;
  }
  return Map.unmodifiable(result);
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

class CoordinatorProfile {
  final int coordinatorId;
  final String rut;
  final String name;
  final String lastname;
  final String phone;
  final String email;
  final String residence;
  final String office;
  final String company;
  final bool hasPicture;

  const CoordinatorProfile({
    required this.coordinatorId,
    required this.rut,
    required this.name,
    required this.lastname,
    required this.phone,
    required this.email,
    required this.residence,
    required this.office,
    required this.company,
    required this.hasPicture,
  });

  factory CoordinatorProfile.fromJson(Map<String, dynamic> json) {
    return CoordinatorProfile(
      coordinatorId: JsonFields.id(json['coordinatorId']),
      rut: JsonFields.text(json['rut']),
      name: JsonFields.text(json['name']),
      lastname: JsonFields.text(json['lastname']),
      phone: JsonFields.text(json['phone']),
      email: JsonFields.text(json['email']),
      residence: JsonFields.text(json['residence']),
      office: JsonFields.text(json['office']),
      company: JsonFields.text(json['company']),
      hasPicture: JsonFields.boolean(json['hasPicture']),
    );
  }
}
