class RequestPassengerMedicalEdit {
  String grupoSanguineo;
  String contactoEmergenciaNombre;
  String contactoEmergenciaRelacion;
  String contactoEmergenciaTelefono;
  String contactoEmergenciaEmail;
  List<String> enfermedades;
  List<String> medicamentos; // Lista para medicamentos con dosis
  List<String> medicamentosEvitar;
  int idPassenger;
  int idTour;

  RequestPassengerMedicalEdit(
      {required this.grupoSanguineo,
      required this.contactoEmergenciaNombre,
      required this.contactoEmergenciaRelacion,
      required this.contactoEmergenciaTelefono,
      required this.contactoEmergenciaEmail,
      required this.enfermedades,
      required this.medicamentos,
      required this.medicamentosEvitar,
      required this.idPassenger,
      required this.idTour});

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
      'idTour': idTour
    };
  }

  @override
  String toString() {
    return 'RequestPassengerMedicalEdit(grupoSanguineo: $grupoSanguineo, '
        'contactoEmergenciaNombre: $contactoEmergenciaNombre, '
        'contactoEmergenciaRelacion: $contactoEmergenciaRelacion, '
        'contactoEmergenciaTelefono: $contactoEmergenciaTelefono, '
        'contactoEmergenciaEmail: $contactoEmergenciaEmail, '
        'enfermedades: $enfermedades, '
        'idPassenger: $idPassenger, '
        'idTour: $idTour, '
        'medicamentos: $medicamentos, '
        'medicamentosEvitar: $medicamentosEvitar)';
  }
}
