import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/main.dart';
import 'package:papigiras_app/runtime/api_destination.dart';

void main() {
  testWidgets(
    'connected app has official title and never exposes LAB controls',
    (tester) async {
      await tester.pumpWidget(
        const PapigirasLab(startScreen: Scaffold(body: Text('Fixture home'))),
      );
      await tester.pump();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'PapiGiras',
      );
      expect(find.text('Fixture home'), findsOneWidget);
      expect(find.textContaining('COPIA RECUPERADA'), findsNothing);
      expect(find.byTooltip('Recorrido ficticio LAB'), findsNothing);
      expect(find.textContaining('LAB'), findsNothing);
    },
    skip: !AppEnvironment.connected,
  );
}
