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
      coordinatorId: (json['coordinatorId'] as num).toInt(),
      rut: json['rut'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastname: json['lastname'] as String? ?? '',
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      token: json['token'] as String? ?? '',
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
      tourId: (json['tourId'] as num).toInt(),
      tourCode: json['tourCode'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      status: json['status'] as String? ?? '',
      clientId: (json['clientId'] as num?)?.toInt() ?? 0,
      clientName: json['clientName'] as String? ?? '',
      course: json['course'] as String? ?? '',
      season: (json['season'] as num?)?.toInt() ?? 0,
      assignmentId: (json['assignmentId'] as num).toInt(),
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
  });

  factory CoordinatorTourDetail.fromJson(Map<String, dynamic> json) {
    return CoordinatorTourDetail(
      tourId: (json['tourId'] as num).toInt(),
      tourCode: json['tourCode'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      status: json['status'] as String? ?? '',
      studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      clientId: (json['clientId'] as num?)?.toInt() ?? 0,
      clientName: json['clientName'] as String? ?? '',
      course: json['course'] as String? ?? '',
      season: (json['season'] as num?)?.toInt() ?? 0,
      branchId: (json['branchId'] as num?)?.toInt() ?? 0,
      branchName: json['branchName'] as String? ?? '',
      assignmentId: (json['assignmentId'] as num).toInt(),
    );
  }
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
      coordinatorId: (json['coordinatorId'] as num).toInt(),
      rut: json['rut'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastname: json['lastname'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      residence: json['residence'] as String? ?? '',
      office: json['office'] as String? ?? '',
      company: json['company'] as String? ?? '',
      hasPicture: json['hasPicture'] as bool? ?? false,
    );
  }
}
