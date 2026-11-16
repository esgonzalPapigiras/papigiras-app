import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/listPassenger.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

import 'passenger_roster_data_test.dart' show person;

class _RosterProvider extends CoordinatorProviders {
  List<PassengerList> rows = [
    person(101, 'M', name: 'Alex Demo', medical: 'Lleno'),
    person(102, 'F', name: 'Bea Demo'),
  ];
  final photoCalls = <(String, String)>[];
  final views = <(String, String, String)>[];
  final shares = <(String, String, String)>[];
  final photos = <String, String>{};
  int loads = 0;
  bool failLoad = false;
  bool failMedical = false;
  bool failPhotos = false;
  Future<void> Function(BuildContext)? view;
  Future<void> Function()? share;
  Future<List<PassengerList>> Function(String)? load;

  @override
  Future<List<PassengerList>> getListPassenger(String tourCode) async {
    loads++;
    if (failLoad)
      throw StateError('Payload técnico ficticio que no debe mostrarse');
    return load?.call(tourCode) ?? List.of(rows);
  }

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async {
    photoCalls.add((rut, tour));
    if (failPhotos) throw StateError('Foto de prueba ausente');
    return Responseimagepassenger(image: photos[rut] ?? '');
  }

  @override
  Future<void> viewDocumentMedicalRecord(
    String tour,
    String id,
    BuildContext context,
    String rut,
  ) async {
    views.add((tour, id, rut));
    if (failMedical) throw StateError('Payload técnico ficticio');
    await view?.call(context);
  }

  @override
  Future<void> shareDocumentMedicalRecord(
    String tour,
    String id,
    String rut,
  ) async {
    shares.add((tour, id, rut));
    if (failMedical) throw StateError('Payload técnico ficticio');
    await share?.call();
  }
}

void main() {
  late _RosterProvider provider;
  late LocationService location;
  late TourSales login;
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    SharedPreferences.setMockInitialValues({});
    LabFixtures.reset();
    provider = _RosterProvider();
    location = LocationService();
    login = TourSales.fromCoordinatorTour(
      coordinator: LabFixtures.coordinator,
      tour: LabFixtures.tour,
    );
    addTearDown(() {
      provider.dispose();
      location.dispose();
      HttpOverrides.global = previous;
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
    });
  });

  Finder row(int id) => find.byKey(ValueKey('roster-passenger-$id'));
  Finder medical(int id) => find.byKey(ValueKey('roster-medical-$id'));
  Finder share(int id) => find.byKey(ValueKey('roster-share-$id'));
  Finder scroll() => find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> show(
    WidgetTester tester, {
    double width = 393,
    double height = 852,
    double scale = 1,
    bool settle = true,
    TourSales? activeLogin,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<LocationService>.value(
        value: location,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ListPassengerCoordScreen(
            login: activeLogin ?? login,
            provider: provider,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 180, scrollable: scroll());
    await tester.pumpAndSettle();
  }

  Future<void> top(WidgetTester tester) async {
    tester.state<ScrollableState>(scroll()).position.jumpTo(0);
    await tester.pumpAndSettle();
  }

  Future<void> quickFilter(WidgetTester tester, String key) async {
    await top(tester);
    final target = find.byKey(ValueKey(key));
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  }

  Future<void> chooseCategory(WidgetTester tester, String category) async {
    await top(tester);
    final reset = find.byKey(const ValueKey('roster-reset-filters'));
    if (reset.evaluate().isNotEmpty) {
      await tester.tap(reset);
      await tester.pumpAndSettle();
    }
    if (category == 'all') return;
    final group = category.startsWith('students') ? 'students' : 'companions';
    await quickFilter(tester, 'roster-filter-$group');
    if (category.endsWith('Male')) {
      await quickFilter(tester, 'roster-sex-male');
    } else if (category.endsWith('Female')) {
      await quickFilter(tester, 'roster-sex-female');
    }
  }

  testWidgets(
    'filtros rápidos de grupo y sexo combinan sin abrir hojas ni perder desconocidos',
    (tester) async {
      provider.rows = [
        person(1, 'M'),
        person(2, 'F'),
        person(3, 'AM'),
        person(4, 'AF'),
        person(5, 'MC'),
        person(6, null),
      ];
      await show(tester);
      expect(find.text('6 de 6 pasajeros'), findsOneWidget);
      expect(find.byKey(const ValueKey('roster-filters')), findsNothing);
      for (final key in [
        'roster-medical-missing',
        'roster-diet-filter',
        'roster-filter-students',
        'roster-filter-companions',
        'roster-sex-male',
        'roster-sex-female',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      for (final pair in [
        ('studentsMale', 1),
        ('studentsFemale', 2),
        ('companionsMale', 3),
        ('companionsFemale', 4),
      ]) {
        await chooseCategory(tester, pair.$1);
        expect(find.text('1 de 6 pasajeros'), findsOneWidget);
        await reveal(tester, row(pair.$2));
        expect(row(pair.$2), findsOneWidget);
      }
      await chooseCategory(tester, 'all');
      expect(find.text('6 de 6 pasajeros'), findsOneWidget);
      await reveal(tester, row(5));
      expect(row(5), findsOneWidget);
      await reveal(tester, row(6));
      expect(row(6), findsOneWidget);
      expect(provider.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un toque cambia cada dimensión y otro toque la desactiva', (
    tester,
  ) async {
    provider.rows = [
      person(910011, 'M'),
      person(910012, 'F'),
      person(910013, 'AM'),
      person(910014, 'AF'),
      person(910015, null),
    ];
    await show(tester);
    await quickFilter(tester, 'roster-sex-male');
    expect(find.text('2 de 5 pasajeros'), findsOneWidget);
    await quickFilter(tester, 'roster-filter-students');
    expect(find.text('1 de 5 pasajeros'), findsOneWidget);
    await reveal(tester, row(910011));
    expect(row(910011), findsOneWidget);
    await quickFilter(tester, 'roster-filter-companions');
    expect(find.text('1 de 5 pasajeros'), findsOneWidget);
    await reveal(tester, row(910013));
    expect(row(910013), findsOneWidget);
    await quickFilter(tester, 'roster-sex-female');
    await reveal(tester, row(910014));
    expect(row(910014), findsOneWidget);
    expect(row(910013), findsNothing);
    await quickFilter(tester, 'roster-sex-female');
    expect(find.text('2 de 5 pasajeros'), findsOneWidget);
    await quickFilter(tester, 'roster-filter-companions');
    expect(find.text('5 de 5 pasajeros'), findsOneWidget);
    expect(provider.loads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orden A–Z/Z–A cambia filas conservando acciones de cada ID', (
    tester,
  ) async {
    provider.rows = [
      person(1, 'M', name: 'Zeta Demo'),
      person(2, 'F', name: 'Álex Demo'),
    ];
    await show(tester);
    expect(
      tester.getTopLeft(row(2)).dy,
      lessThan(tester.getTopLeft(row(1)).dy),
    );
    await tester.tap(find.byKey(const ValueKey('roster-sort')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(row(1)).dy,
      lessThan(tester.getTopLeft(row(2)).dy),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('roster-sort'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'foto usa RUT y gira con fallback local para ausente o corrupta',
    (tester) async {
      provider.rows = [person(101, 'M'), person(102, 'F'), person(103, 'AM')];
      provider.photos['LAB-101'] = base64Encode(TileProvider.transparentImage);
      provider.photos['LAB-102'] = 'base64-inválido';
      provider.photos['LAB-103'] = base64Encode([137, 80, 78, 71, 0, 0, 0, 0]);
      await show(tester);
      await reveal(tester, row(103));
      expect(
        provider.photoCalls.every(
          (p) =>
              p.$1.startsWith('LAB-') && p.$2 == login.tourSalesId.toString(),
        ),
        isTrue,
      );
      expect(provider.photoCalls.any((p) => p.$1 == '101'), isFalse);
      await top(tester);
      await reveal(tester, row(101));
      expect(find.byKey(const ValueKey('roster-image-101')), findsOneWidget);
      final image = tester.widget<Image>(
        find.byKey(const ValueKey('roster-image-101')),
      );
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, 144);
      expect(
        tester.getSize(find.byKey(const ValueKey('roster-avatar-101'))),
        const Size.square(48),
      );
      expect(
        find.descendant(
          of: row(102),
          matching: find.byIcon(Icons.person_outline),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'carga fotos sólo al recorrer filas y reconsulta las desalojadas de caché24',
    (tester) async {
      provider.rows = [
        for (var i = 1; i <= 36; i++)
          person(i, 'M', name: 'Persona ${i.toString().padLeft(2, '0')}'),
      ];
      await show(tester);
      expect(provider.photoCalls.length, lessThan(10));
      await reveal(tester, row(32));
      expect(
        provider.photoCalls.map((p) => p.$1).toSet().length,
        greaterThan(24),
      );
      final callsBefore = provider.photoCalls
          .where((p) => p.$1 == 'LAB-1')
          .length;
      await top(tester);
      await reveal(tester, row(1));
      expect(
        provider.photoCalls.where((p) => p.$1 == 'LAB-1').length,
        greaterThan(callsBefore),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ficha médica a la derecha abre el visor; pendiente informa sin descargar',
    (tester) async {
      await show(tester);
      expect(tester.widget(medical(101)), isA<TextButton>());
      await reveal(tester, medical(102));
      expect(tester.widget(medical(102)), isA<TextButton>());
      expect(
        find.descendant(of: row(102), matching: find.text('Sin ficha médica')),
        findsOneWidget,
      );
      expect(share(102), findsNothing);
      await tester.tap(medical(102));
      await tester.pumpAndSettle();
      expect(provider.views, isEmpty);
      expect(provider.shares, isEmpty);
      expect(
        find.text('Este pasajero aún no tiene una ficha médica guardada.'),
        findsOneWidget,
      );
      await top(tester);
      await reveal(tester, medical(101));
      await tester.tap(medical(101));
      await tester.pumpAndSettle();
      expect(provider.views, [
        (login.tourSalesId.toString(), '101', 'LAB-101'),
      ]);
      expect(share(101), findsNothing);
      expect(provider.shares, isEmpty);
      expect(
        find.descendant(
          of: medical(101),
          matching: find.byIcon(Icons.medical_information_outlined),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'acción pendiente bloquea duplicados y error se muestra sin payload técnico',
    (tester) async {
      final pending = Completer<void>();
      provider.view = (_) => pending.future;
      await show(tester);
      await reveal(tester, medical(101));
      await tester.tap(medical(101));
      await tester.pump();
      expect(provider.views.length, 1);
      expect(share(101), findsNothing);
      expect(tester.widget<ButtonStyleButton>(medical(101)).onPressed, isNull);
      pending.completeError(StateError('Payload técnico ficticio'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos abrir la ficha médica. Inténtalo nuevamente.'),
        findsOneWidget,
      );
      expect(find.textContaining('Payload técnico'), findsNothing);
      expect(
        tester.widget<ButtonStyleButton>(medical(101)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh y reanudar vuelven a leer fotos sin cambiar filtro seleccionado',
    (tester) async {
      await show(tester);
      await chooseCategory(tester, 'studentsMale');
      final before = provider.photoCalls.length;
      await top(tester);
      await tester.tap(find.byKey(const ValueKey('roster-refresh')));
      await tester.pumpAndSettle();
      expect(provider.photoCalls.length, greaterThan(before));
      expect(row(102), findsNothing);
      expect(row(101), findsOneWidget);
      final loads = provider.loads;
      // The search TextField observes lifecycle too: use the real OS sequence.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(provider.loads, greaterThan(loads));
      expect(row(102), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('volver de la ficha conserva listado y recarga fotos', (
    tester,
  ) async {
    provider.view = (context) => Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver de ficha de prueba'),
            ),
          ),
        ),
      ),
    );
    await show(tester);
    await reveal(tester, medical(101));
    final state = tester.state(find.byType(ListPassengerCoordScreen));
    await tester.tap(medical(101));
    await tester.pumpAndSettle();
    final before = provider.loads;
    await tester.tap(find.text('Volver de ficha de prueba'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ListPassengerCoordScreen)), same(state));
    expect(provider.loads, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'carga, reintento, vacío y error posterior no inventan personas ni exponen error',
    (tester) async {
      provider.failLoad = true;
      await show(tester);
      expect(find.text('No pudimos cargar los pasajeros.'), findsOneWidget);
      expect(find.textContaining('Payload técnico'), findsNothing);
      provider.failLoad = false;
      provider.rows = [];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('No hay pasajeros en esta gira.'), findsOneWidget);
      provider.rows = [person(101, 'M')];
      await tester.tap(find.byKey(const ValueKey('roster-refresh')));
      await tester.pumpAndSettle();
      provider.failLoad = true;
      await tester.tap(find.byKey(const ValueKey('roster-refresh')));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos actualizar el listado. Inténtalo nuevamente.'),
        findsOneWidget,
      );
      await reveal(tester, row(101));
      expect(row(101), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320px texto1,6 nombres largos y fotos fallidas mantienen controles y scroll',
    (tester) async {
      provider.rows = [
        person(
          101,
          'AF',
          name: List.filled(5, 'Nombre ficticio extenso').join(' '),
          medical: 'Lleno',
        ),
      ];
      provider.failPhotos = true;
      await show(tester, width: 320, height: 740, scale: 1.6);
      await reveal(tester, medical(101));
      expect(
        tester.getSize(medical(101)).shortestSide,
        greaterThanOrEqualTo(44),
      );
      expect(share(101), findsNothing);
      expect(
        tester.widget<ButtonStyleButton>(medical(101)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'API anterior no convierte clasificación ausente en totales cero',
    (tester) async {
      provider.rows = [person(101, null, medical: 'Lleno'), person(102, null)];
      await show(tester);
      expect(find.text('2 de 2 pasajeros'), findsOneWidget);
      expect(find.text('Dietas especiales · —'), findsOneWidget);
      expect(find.text('Clasificación no disponible'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('roster-filter-studentsMale')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('roster-filter-companionsFemale')),
        findsNothing,
      );
      await reveal(tester, medical(101));
      expect(
        tester.widget<ButtonStyleButton>(medical(101)).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<ButtonStyleButton>(medical(101)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PM/PF y APM/APF aparecen en filtros de acompañantes sin cambiar datos',
    (tester) async {
      provider.rows = [
        person(1, 'PM'),
        person(2, 'PF'),
        person(3, 'APM'),
        person(4, 'APF'),
        person(5, 'MC'),
      ];
      await show(tester);
      await chooseCategory(tester, 'companions');
      expect(find.text('4 de 5 pasajeros'), findsOneWidget);
      await chooseCategory(tester, 'students');
      expect(find.text('0 de 5 pasajeros'), findsOneWidget);
      await chooseCategory(tester, 'companionsMale');
      expect(find.text('2 de 5 pasajeros'), findsOneWidget);
      await reveal(tester, row(1));
      expect(row(1), findsOneWidget);
      await reveal(tester, row(3));
      expect(row(3), findsOneWidget);
      expect(row(2), findsNothing);
      await chooseCategory(tester, 'companionsFemale');
      expect(find.text('2 de 5 pasajeros'), findsOneWidget);
      await reveal(tester, row(2));
      expect(row(2), findsOneWidget);
      await reveal(tester, row(4));
      expect(row(4), findsOneWidget);
      expect(row(3), findsNothing);
      expect(provider.rows.map((person) => person.passengerSex), [
        'PM',
        'PF',
        'APM',
        'APF',
        'MC',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'búsqueda inmediata combina sexo y grupo, limpiar conserva filtro',
    (tester) async {
      provider.rows = [
        person(
          910011,
          'F',
          name: 'Sofía Ejemplo LAB',
          surname: 'Núñez',
          rut: '99.000.115-K',
        ),
        person(910012, 'M', name: 'Mateo Ejemplo LAB', rut: '99.000.123-4'),
        person(910013, 'AF', name: 'Valentina Ejemplo LAB', surname: 'Núñez'),
      ];
      await show(tester);
      final search = find.byKey(const ValueKey('roster-search'));
      await tester.enterText(search, 'nunez');
      await tester.pumpAndSettle();
      expect(row(910011), findsOneWidget);
      expect(row(910012), findsNothing);
      expect(find.text('2 de 3 pasajeros'), findsOneWidget);
      await chooseCategory(tester, 'companions');
      expect(row(910011), findsNothing);
      expect(row(910013), findsOneWidget);
      await tester.enterText(search, '99.000.115-k');
      await tester.pumpAndSettle();
      expect(
        find.text('No encontramos pasajeros con esa búsqueda.'),
        findsOneWidget,
      );
      await chooseCategory(tester, 'all');
      expect(row(910011), findsOneWidget);
      expect(row(910013), findsNothing);
      await tester.tap(find.byKey(const ValueKey('roster-search-clear')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(find.text('3 de 3 pasajeros'), findsOneWidget);
      expect(provider.loads, 1); // Search is local; no request per keystroke.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dieta especial junto al pasajero, tradicional y vacía sin indicador',
    (tester) async {
      provider.rows = [
        person(
          910011,
          'F',
          name: 'Sofía LAB',
          diet: 'Vegetariana',
          medical: 'Lleno',
        ),
        person(910012, 'M', name: 'Mateo LAB', diet: ' Tradicional '),
        person(910013, 'AF', name: 'Valentina LAB', diet: ''),
      ];
      await show(tester);
      await tester.enterText(
        find.byKey(const ValueKey('roster-search')),
        'Sofía',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('roster-diet-910011')), findsOneWidget);
      expect(find.text('Dieta: Vegetariana'), findsOneWidget);
      expect(
        tester.widget<ButtonStyleButton>(medical(910011)).onPressed,
        isNotNull,
      );
      expect(share(910011), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('roster-search')),
        'LAB',
      );
      await tester.pumpAndSettle();
      await reveal(tester, row(910013));
      expect(find.byKey(const ValueKey('roster-diet-910012')), findsNothing);
      expect(find.byKey(const ValueKey('roster-diet-910013')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actualizar conserva búsqueda y controles de filtros accesibles',
    (tester) async {
      await show(tester);
      final filters = find.byKey(const ValueKey('roster-filter-students'));
      expect(tester.getSize(filters).shortestSide, greaterThanOrEqualTo(44));
      final medicalFilter = find.byKey(
        const ValueKey('roster-medical-missing'),
      );
      // Compact iPhone controls retain the same 44 pt hit region as other filters.
      expect(tester.getSize(medicalFilter).height, greaterThanOrEqualTo(44));
      await tester.enterText(
        find.byKey(const ValueKey('roster-search')),
        'Alex',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roster-refresh')));
      await tester.pumpAndSettle();
      expect(row(101), findsOneWidget);
      expect(row(102), findsNothing);
      expect(provider.loads, 2);
    },
  );

  testWidgets('320px texto al doble, búsqueda y dieta larga no desbordan', (
    tester,
  ) async {
    provider.rows = [
      person(
        910011,
        'AF',
        name: 'Sofía Ejemplo LAB',
        diet:
            'Dieta especial con una descripción extensa conservada desde la ficha',
      ),
    ];
    await show(tester, width: 320, height: 740, scale: 2);
    await reveal(tester, find.byKey(const ValueKey('roster-diet-910011')));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cambios de texto por accesibilidad actualizan la lista sin onChanged',
    (tester) async {
      await show(tester);
      final search = tester.widget<TextField>(
        find.byKey(const ValueKey('roster-search')),
      );
      search.controller!.text = 'Bea';
      await tester.pumpAndSettle();
      expect(row(101), findsNothing);
      expect(row(102), findsOneWidget);
      search.controller!.clear();
      await tester.pumpAndSettle();
      expect(row(101), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'categoría, ficha, dieta y búsqueda se combinan y se limpian independientemente',
    (tester) async {
      provider.rows = [
        person(
          910011,
          'AM',
          name: 'Alex Ensayo',
          medical: 'Lleno',
          diet: 'Vegetariana',
        ),
        person(910012, 'APM', name: 'Beatriz Ensayo', diet: 'Vegana'),
        person(910013, 'AF', name: 'Clara Ensayo', diet: 'Tradicional'),
        person(910014, 'F', name: 'Dalia Ensayo', diet: 'Sin gluten'),
        person(910015, null, name: 'Elsa Ensayo', diet: 'Sin lactosa'),
      ];
      await show(tester);
      final search = find.byKey(const ValueKey('roster-search'));
      final missing = find.byKey(const ValueKey('roster-medical-missing'));
      final diets = find.byKey(const ValueKey('roster-diet-filter'));
      await chooseCategory(tester, 'companions');
      expect(find.text('3 de 5 pasajeros'), findsOneWidget);
      await tester.tap(missing);
      await tester.pumpAndSettle();
      expect(find.text('2 de 5 pasajeros'), findsOneWidget);
      await tester.tap(diets);
      await tester.pumpAndSettle();
      expect(find.text('1 de 5 pasajeros'), findsOneWidget);
      expect(find.text('Sin ficha médica · 4'), findsOneWidget);
      expect(find.text('Dietas especiales · 4'), findsOneWidget);
      await tester.enterText(search, 'beatriz');
      await tester.pumpAndSettle();
      await reveal(tester, row(910012));
      expect(
        find.byKey(const ValueKey('roster-companion-910012')),
        findsOneWidget,
      );
      expect(row(910014), findsNothing);
      await top(tester);
      await tester.tap(find.byKey(const ValueKey('roster-search-clear')));
      await tester.pumpAndSettle();
      expect(find.text('1 de 5 pasajeros'), findsOneWidget);
      expect(provider.loads, 1);
      await tester.tap(find.byKey(const ValueKey('roster-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('1 de 5 pasajeros'), findsOneWidget);
      expect(provider.loads, 2);

      // Removing the medical filter leaves the diet and category active.
      await tester.tap(missing);
      await tester.pumpAndSettle();
      expect(find.text('2 de 5 pasajeros'), findsOneWidget);
      await reveal(tester, medical(910011));
      expect(
        tester.widget<ButtonStyleButton>(medical(910011)).onPressed,
        isNotNull,
      );
      await top(tester);
      await tester.tap(diets);
      await tester.pumpAndSettle();
      expect(find.text('3 de 5 pasajeros'), findsOneWidget);

      // Reset all filters keeps the user's search; clearing it restores all.
      await tester.enterText(search, 'Beatriz');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roster-reset-filters')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, 'Beatriz');
      expect(find.text('1 de 5 pasajeros'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('roster-search-clear')));
      await tester.pumpAndSettle();
      expect(find.text('5 de 5 pasajeros'), findsOneWidget);
      expect(provider.loads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'badge acompaña todos los alias confirmados sin inferir del tipo',
    (tester) async {
      final codes = [
        'AM',
        'PM',
        'APM',
        'AF',
        'PF',
        'APF',
        'M',
        'F',
        'MC',
        null,
      ];
      provider.rows = [
        for (final (index, code) in codes.indexed)
          person(
            910011 + index,
            code,
            name: 'Persona Alias${index.toString().padLeft(2, '0')}',
            type: 'AF',
          ),
      ];
      await show(tester);
      final search = find.byKey(const ValueKey('roster-search'));
      for (var index = 0; index < codes.length; index++) {
        await top(tester);
        await tester.enterText(
          search,
          'Alias${index.toString().padLeft(2, '0')}',
        );
        await tester.pumpAndSettle();
        final id = 910011 + index;
        await reveal(tester, row(id));
        expect(
          find.byKey(ValueKey('roster-companion-$id')),
          index < 6 ? findsOneWidget : findsNothing,
        );
      }
      expect(provider.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dietas parciales no inventan cero y conservan las conocidas al filtrar',
    (tester) async {
      final missingInfo = person(910012, 'M', name: 'Sin información LAB');
      provider.rows = [
        person(910011, 'AF', name: 'Dieta conocida LAB', diet: 'Vegetariana'),
        missingInfo,
      ];
      await show(tester);
      expect(find.text('Dietas especiales · —'), findsOneWidget);
      final diets = find.byKey(const ValueKey('roster-diet-filter'));
      await tester.tap(diets);
      await tester.pumpAndSettle();
      expect(find.text('1 de 2 pasajeros'), findsOneWidget);
      expect(
        find.text('Hay pasajeros sin información de dieta.'),
        findsOneWidget,
      );
      await reveal(tester, row(910011));
      expect(find.text('Dieta: Vegetariana'), findsOneWidget);
      expect(row(910012), findsNothing);

      provider.rows = [missingInfo];
      await top(tester);
      await tester.tap(find.byKey(const ValueKey('roster-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('0 de 1 pasajeros'), findsOneWidget);
      expect(find.text('Dietas especiales · —'), findsOneWidget);
      expect(
        find.text('Hay pasajeros sin información de dieta.'),
        findsOneWidget,
      );

      provider.rows = [];
      await tester.tap(find.byKey(const ValueKey('roster-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Dietas especiales · 0'), findsOneWidget);
      expect(find.text('No hay pasajeros en esta gira.'), findsOneWidget);
      expect(
        find.text('Hay pasajeros sin información de dieta.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nombres completos usan capitalización Pilo y evitan repetir apellidos legacy',
    (tester) async {
      provider.rows = [
        person(
          910011,
          'F',
          name: 'SOFÍA',
          surname: 'NÚÑEZ EJEMPLO',
          rut: '99.000.111-K',
        ),
        person(
          910012,
          'M',
          name: 'MATEO EJEMPLO LAB',
          surname: 'EJEMPLO LAB',
          rut: '99.000.112-K',
        ),
      ];
      await show(tester);
      final search = find.byKey(const ValueKey('roster-search'));
      await tester.enterText(search, '99000111');
      await tester.pumpAndSettle();
      expect(find.text('Sofía Núñez Ejemplo'), findsOneWidget);
      await tester.enterText(search, '99000112');
      await tester.pumpAndSettle();
      expect(find.text('Mateo Ejemplo Lab'), findsOneWidget);
      expect(find.text('Mateo Ejemplo Lab Ejemplo Lab'), findsNothing);
      expect(provider.rows.first.passengerName, 'SOFÍA');
      expect(provider.rows.last.passengerApellidos, 'EJEMPLO LAB');
    },
  );

  testWidgets(
    'refresh actualiza fichas, acciones y conteos conservando Sin ficha y búsqueda',
    (tester) async {
      provider.rows = [
        person(910011, 'M', name: 'Alex Ensayo', medical: 'Lleno'),
        person(910012, 'F', name: 'Bea Ensayo'),
        person(910013, 'AF', name: 'Caro Ensayo'),
      ];
      await show(tester);
      final missing = find.byKey(const ValueKey('roster-medical-missing'));
      final refresh = find.byKey(const ValueKey('roster-refresh'));
      final search = find.byKey(const ValueKey('roster-search'));
      expect(find.text('Sin ficha médica · 2'), findsOneWidget);
      await tester.tap(missing);
      await tester.pumpAndSettle();
      expect(find.text('2 de 3 pasajeros'), findsOneWidget);

      // The next response changes saved status in both directions.
      provider.rows = [
        person(910011, 'M', name: 'Alex Ensayo'),
        person(910012, 'F', name: 'Bea Ensayo', medical: 'Lleno'),
        person(910013, 'AF', name: 'Caro Ensayo', medical: 'Lleno'),
      ];
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(find.text('Sin ficha médica · 1'), findsOneWidget);
      expect(find.text('1 de 3 pasajeros'), findsOneWidget);
      await reveal(tester, medical(910011));
      expect(tester.widget(medical(910011)), isA<TextButton>());
      expect(share(910011), findsNothing);
      expect(row(910012), findsNothing);

      await top(tester);
      await tester.tap(missing);
      await tester.pumpAndSettle();
      await tester.enterText(search, 'Bea');
      await tester.pumpAndSettle();
      await reveal(tester, medical(910012));
      expect(tester.widget(medical(910012)), isA<TextButton>());
      expect(
        tester.widget<ButtonStyleButton>(medical(910012)).onPressed,
        isNotNull,
      );
      expect(share(910012), findsNothing);

      await top(tester);
      await tester.tap(missing);
      await tester.pumpAndSettle();
      expect(find.text('0 de 3 pasajeros'), findsOneWidget);
      provider.rows = [
        person(910011, 'M', name: 'Alex Ensayo'),
        person(910012, 'F', name: 'Bea Ensayo'),
        person(910013, 'AF', name: 'Caro Ensayo', medical: 'Lleno'),
      ];
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(find.text('Sin ficha médica · 2'), findsOneWidget);
      expect(find.text('1 de 3 pasajeros'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, 'Bea');
      await reveal(tester, medical(910012));
      expect(tester.widget(medical(910012)), isA<TextButton>());
      expect(share(910012), findsNothing);
      await tester.tap(medical(910012));
      await tester.pumpAndSettle();
      expect(provider.views, isEmpty);
      expect(provider.shares, isEmpty);
      expect(provider.loads, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
