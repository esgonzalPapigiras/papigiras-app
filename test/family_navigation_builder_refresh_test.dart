import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';

class _VisitedMap extends StatefulWidget {
  const _VisitedMap({required this.locationControl});

  final bool locationControl;

  @override
  State<_VisitedMap> createState() => _VisitedMapState();
}

class _VisitedMapState extends State<_VisitedMap> {
  final draft = TextEditingController();

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('Mapa visitado'),
        if (widget.locationControl) const Text('Ubicación'),
        TextField(controller: draft),
        FilledButton(
          onPressed: () => FamilyNavigationScope.maybeOf(context)!.back(),
          child: const Text('Volver al inicio'),
        ),
      ],
    ),
  );
}

void main() {
  for (final reassemble in [false, true]) {
    testWidgets(
      'visited section refresh preserves state, reassemble: $reassemble',
      (tester) async {
        final locationEnabled = ValueNotifier(false);
        addTearDown(locationEnabled.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: locationEnabled,
              builder: (context, enabled, _) => FamilyNavigation(
                pilo: true,
                immersiveMap: true,
                coordinatorTools: true,
                builders: {
                  FamilySection.home: (context) => Scaffold(
                    body: FilledButton(
                      onPressed: () => FamilyNavigationScope.maybeOf(
                        context,
                      )!.select(FamilySection.map),
                      child: const Text('Abrir mapa'),
                    ),
                  ),
                  FamilySection.map: (_) =>
                      _VisitedMap(locationControl: enabled),
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abrir mapa'));
        await tester.pumpAndSettle();
        expect(find.text('Mapa visitado'), findsOneWidget);
        expect(find.text('Ubicación'), findsNothing);
        final originalMap = tester.state<_VisitedMapState>(
          find.byType(_VisitedMap),
        );
        const pendingText = 'Estado local ficticio que debe conservarse';
        await tester.enterText(find.byType(TextField), pendingText);
        tester.testTextInput.hide();

        // Rebuilding the shell with a new section factory represents a UI change
        // while the old route is already cached in its section Navigator.
        locationEnabled.value = true;
        await tester.pumpAndSettle();
        if (reassemble) {
          final reload = tester.binding.reassembleApplication();
          await tester.pumpAndSettle();
          await reload;
        }
        expect(find.text('Ubicación'), findsOneWidget);
        expect(tester.state(find.byType(_VisitedMap)), same(originalMap));
        expect(originalMap.draft.text, pendingText);

        await tester.tap(find.text('Volver al inicio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abrir mapa'));
        await tester.pumpAndSettle();
        expect(find.text('Ubicación'), findsOneWidget);
        expect(tester.state(find.byType(_VisitedMap)), same(originalMap));
        expect(originalMap.draft.text, pendingText);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
