/// Identity comes from the tour assignment, never from the logged-in user's photo.
class CrewCoordinator {
  const CrewCoordinator({
    required this.id,
    required this.name,
    required this.rut,
  });
  final int? id;
  final String name;
  final String rut;
  factory CrewCoordinator.fromJson(Map<String, dynamic> json) {
    final id = json['coordinatorId'];
    if (id != null && (id is! int || id <= 0)) {
      throw const FormatException('Coordinador inválido.');
    }
    return CrewCoordinator(
      id: id as int?,
      name: (json['name'] as String? ?? '').trim(),
      rut: (json['rut'] as String? ?? '').trim(),
    );
  }
}
