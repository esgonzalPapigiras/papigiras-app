import 'package:flutter/material.dart';
import '../dto/coordinator_session.dart';
import '../dto/responseAttorney.dart';
import '../pages/coordinator/coordinatorTourSelection.dart';
import '../pages/attorney/fatherWelcome.dart';
import '../pages/alumns/indexpassenger.dart';

Widget localRoleDestination(String role, Map<String, dynamic> session) {
  if (role == 'coordinator') {
    return CoordinatorTourSelectionScreen(
      coordinator: CoordinatorLogin.fromJson(session),
    );
  }
  final login = ResponseAttorney.fromJson(session);
  return role == 'attorney'
      ? WelcomeFatherScreen(login: login)
      : TravelPassengerDashboard(login: login);
}
