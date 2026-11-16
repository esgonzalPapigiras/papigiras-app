import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/local_access.dart';

// Opt-in: connects only to localhost and explicitly preserved synthetic IDs.
// A failed assertion never prints returned profiles, records or credentials.
void main() {
  final password = Platform.environment['PAPIGIRAS_LAB_ACCESS_PASSWORD'];
  test(
    'local recovered API accepts only explicit demo role sessions and local PDFs',
    () async {
      final access = LocalAccessClient();
      final api = LabApiClient();
      addTearDown(access.close);
      addTearDown(api.close);
      await access.unlock(password!);
      for (final role in ['coordinator', 'passenger', 'attorney']) {
        final profileId = role == 'coordinator' ? 910001 : 910011;
        final session = await access.session(role, profileId);
        final lookup = role == 'coordinator'
            ? CoordinatorLogin.fromJson(session).rut
            : ResponseAttorney.fromJson(session).passengerIdentificacion ?? '';
        expect(
          lookup.isNotEmpty,
          isTrue,
          reason:
              'El perfil ficticio debe tener identificador para búsqueda restringida.',
        );
        final page = await access.profiles(role, query: lookup);
        expect(
          page.items.any((item) => item.id == profileId),
          isTrue,
          reason: 'La búsqueda debe encontrar sólo el perfil demo solicitado.',
        );
        if (role == 'coordinator') {
          final parsed = CoordinatorLogin.fromJson(session);
          expect(
            parsed.coordinatorId == profileId,
            isTrue,
            reason: 'La sesión debe corresponder al coordinador ficticio.',
          );
          expect(parsed.token.startsWith('Bearer '), isTrue);
        } else {
          final parsed = ResponseAttorney.fromJson(session);
          expect(
            parsed.passengerId == profileId && parsed.tourId == 910001,
            isTrue,
            reason: 'La sesión debe corresponder al alumno y gira ficticios.',
          );
          expect(
            parsed.isActive == true &&
                (parsed.tokenKey ?? '').startsWith('Bearer '),
            isTrue,
          );
          if (role == 'attorney') {
            final pdf = await api.post(
              LabApi.uri('/app/services/get/pdf/medical-records', {
                'tourId': '910001',
                'idPassenger': '910011',
              }),
              headers: {'Authorization': parsed.tokenKey!},
            );
            expect(
              pdf.bodyBytes.length >= 5 &&
                  ascii.decode(
                        pdf.bodyBytes.take(5).toList(),
                        allowInvalid: true,
                      ) ==
                      '%PDF-',
              isTrue,
              reason: 'La ficha ficticia debe llegar como PDF local.',
            );
          }
        }
      }
    },
    skip: password == null || password.isEmpty,
  );
}
