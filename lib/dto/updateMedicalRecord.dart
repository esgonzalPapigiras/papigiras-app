class RequestPassengerMedicalEdit {
  String grupoSanguineo;
  String contactoEmergenciaNombre;
  String contactoEmergenciaRelacion;
  String contactoEmergenciaTelefono;
  String contactoEmergenciaEmail;
  List<String> enfermedades;
  List<String> medicamentos;
  List<String> medicamentosEvitar;
  int idPassenger;
  int idTour;

  bool requiereCuidadosEspeciales;
  String? cuidadosEspeciales;

  // NEW COVERAGE FIELDS
  bool tieneFonasa;
  bool tieneIsapre;
  String? nombreIsapre;

  RequestPassengerMedicalEdit({
    required this.grupoSanguineo,
    required this.contactoEmergenciaNombre,
    required this.contactoEmergenciaRelacion,
    required this.contactoEmergenciaTelefono,
    required this.contactoEmergenciaEmail,
    required this.enfermedades,
    required this.medicamentos,
    required this.medicamentosEvitar,
    required this.idPassenger,
    required this.idTour,
    required this.requiereCuidadosEspeciales,
    this.cuidadosEspeciales,

    // NEW
    required this.tieneFonasa,
    required this.tieneIsapre,
    this.nombreIsapre,
  });

  Map<String, dynamic> toJson() {
    return {
      'grupoSanguineo': grupoSanguineo,
      'contactoEmergenciaNombre': contactoEmergenciaNombre,
      'contactoEmergenciaRelacion': contactoEmergenciaRelacion,
      'contactoEmergenciaTelefono': contactoEmergenciaTelefono,
      'contactoEmergenciaEmail': contactoEmergenciaEmail,
      'enfermedades': enfermedades,
      'medicamentos': medicamentos,
      'medicamentosEvitar': medicamentosEvitar,
      'idPassenger': idPassenger,
      'idTour': idTour,
      'requiereCuidadosEspeciales': requiereCuidadosEspeciales,
      'cuidadosEspeciales': cuidadosEspeciales,

      // NEW
      'tieneFonasa': tieneFonasa,
      'tieneIsapre': tieneIsapre,
      'nombreIsapre': nombreIsapre,
    };
  }

  @override
  String toString() {
    return 'RequestPassengerMedicalEdit('
        'grupoSanguineo: $grupoSanguineo, '
        'contactoEmergenciaNombre: $contactoEmergenciaNombre, '
        'contactoEmergenciaRelacion: $contactoEmergenciaRelacion, '
        'contactoEmergenciaTelefono: $contactoEmergenciaTelefono, '
        'contactoEmergenciaEmail: $contactoEmergenciaEmail, '
        'enfermedades: $enfermedades, '
        'medicamentos: $medicamentos, '
        'medicamentosEvitar: $medicamentosEvitar, '
        'idPassenger: $idPassenger, '
        'idTour: $idTour, '
        'requiereCuidadosEspeciales: $requiereCuidadosEspeciales, '
        'cuidadosEspeciales: $cuidadosEspeciales, '
        'tieneFonasa: $tieneFonasa, '
        'tieneIsapre: $tieneIsapre, '
        'nombreIsapre: $nombreIsapre'
        ')';
  }
}
