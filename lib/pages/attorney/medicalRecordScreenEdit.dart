import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';

/// Compatibility entry point; all family editing now shares the initial form.
class MedicalRecordScreenEdit extends StatelessWidget {
  const MedicalRecordScreenEdit({
    super.key,
    required this.login,
    required this.record,
  });
  final ResponseAttorney login;
  final PassengersMedicalRecordDTO record;
  @override
  Widget build(BuildContext context) => MedicalRecordScreen(
    login: login,
    savedRecord: record,
    startEditing: true,
  );
}
