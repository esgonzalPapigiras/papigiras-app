class RequestPassengerMedical {
  String nombres;
  String apellidos;
  String curso;
  String colegio;
  String comuna;
  String rut;
  String grupoSanguineo;
  String contactoEmergenciaNombre;
  String contactoEmergenciaRelacion;
  String contactoEmergenciaTelefono;
  String contactoEmergenciaEmail;
  bool tieneFonasa;
  bool tieneIsapre;
  String? isapre;
  bool tieneEnfermedades;
  String? enfermedades;
  bool tomaMedicamentos;
  List<Map<String, String>> medicamentos; // Lista para medicamentos con dosis
  bool evitarMedicamentos;
  String? medicamentosEvitar;
  bool requiereCuidadosEspeciales;
  String? cuidadosEspeciales;
  DateTime fechaNacimiento;
  DateTime fechaAutorizacion;
  int idPassenger;
  int idTour;

  RequestPassengerMedical(
      {required this.nombres,
      required this.apellidos,
      required this.curso,
      required this.colegio,
      required this.comuna,
      required this.rut,
      required this.grupoSanguineo,
      required this.contactoEmergenciaNombre,
      required this.contactoEmergenciaRelacion,
      required this.contactoEmergenciaTelefono,
      required this.contactoEmergenciaEmail,
      required this.tieneFonasa,
      required this.tieneIsapre,
      this.isapre,
      required this.tieneEnfermedades,
      this.enfermedades,
      required this.tomaMedicamentos,
      required this.medicamentos,
      required this.evitarMedicamentos,
      this.medicamentosEvitar,
      required this.requiereCuidadosEspeciales,
      this.cuidadosEspeciales,
      required this.fechaNacimiento,
      required this.fechaAutorizacion,
      required this.idPassenger,
      required this.idTour});

  Map<String, dynamic> toJson() {
    return {
      'nombres': nombres,
      'apellidos': apellidos,
      'curso': curso,
      'colegio': colegio,
      'comuna': comuna,
      'rut': rut,
      'grupoSanguineo': grupoSanguineo,
      'contactoEmergenciaNombre': contactoEmergenciaNombre,
      'contactoEmergenciaRelacion': contactoEmergenciaRelacion,
      'contactoEmergenciaTelefono': contactoEmergenciaTelefono,
      'contactoEmergenciaEmail': contactoEmergenciaEmail,
      'tieneFonasa': tieneFonasa,
      'tieneIsapre': tieneIsapre,
      'isapre': isapre,
      'tieneEnfermedades': tieneEnfermedades,
      'enfermedades': enfermedades,
      'tomaMedicamentos': tomaMedicamentos,
      'medicamentos': medicamentos,
      'evitarMedicamentos': evitarMedicamentos,
      'medicamentosEvitar': medicamentosEvitar,
      'requiereCuidadosEspeciales': requiereCuidadosEspeciales,
      'cuidadosEspeciales': cuidadosEspeciales,
      'fechaNacimiento': fechaNacimiento.toIso8601String(),
      'fechaAutorizacion': fechaAutorizacion.toIso8601String(),
      'idPassenger': idPassenger,
      'idTour': idTour
    };
  }
}
