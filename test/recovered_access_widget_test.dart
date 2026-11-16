import 'dart:convert';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/local_access.dart';
import 'package:papigiras_app/lab/local_access_panel.dart';
import 'package:papigiras_app/lab/preferences.dart';

void main() {
  testWidgets(
    'local selector requires explicit unlock and never auto-selects a profile',
    (tester) async {
      var calls = 0;
      final client = LocalAccessClient(
        client: LabApiClient(
          transport: MockClient((request) async {
            calls++;
            if (request.url.path.endsWith('/operator/login'))
              return http.Response(
                '{"token":"Bearer synthetic-operator"}',
                200,
              );
            if (request.url.path.endsWith('/session')) {
              return http.Response(
                jsonEncode(LabFixtures.passenger.toJson()),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response(
              '{"items":[{"profileId":42,"label":"Perfil sintético","detail":"Gira ficticia"}],"offset":0,"limit":25,"hasMore":false}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LocalAccessPanel(
            role: 'passenger',
            destination: (_, __) =>
                const Scaffold(body: Text('Sesión sintética abierta')),
            client: client,
          ),
        ),
      );
      expect(calls, 0);
      await tester.enterText(find.byType(TextField), 'synthetic-password');
      await tester.runAsync(() async {
        await tester.tap(find.text('Abrir perfiles locales'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        calls,
        1,
        reason: 'Unlock must not automatically disclose a catalog',
      );
      expect(find.text('Perfil sintético'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Perfil sintético');
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Buscar'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        calls,
        2,
        reason: 'The catalog is read only after an explicit search',
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.widgetWithText(ListTile, 'Perfil sintético'), findsOneWidget);
      expect(find.text('synthetic-password'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString('token'),
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ListTile, 'Perfil sintético'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('Sesión sintética abierta'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('userRole'),
        'passenger',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
