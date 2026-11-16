import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/maps/trip_hito_content.dart';
import 'package:papigiras_app/maps/trip_hito_edit_sheet.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/pages/attorney/binnacledetailFather.dart';
import 'package:papigiras_app/pages/coordinator/detailbinnacleCoodinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

typedef _Save =
    Future<void> Function(String title, String description, String closingNote);

class _DetailProvider extends CoordinatorProviders {
  _DetailProvider(this.detail);
  final DetailHitoList detail;
  int calls = 0;
  bool fail = false;
  final updates = <Map<String, String>>[];

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tourId) async {
    calls++;
    if (fail) throw StateError('PAYLOAD_TECNICO_NO_VISIBLE');
    return detail;
  }

  @override
  Future<void> updateHito({
    required String idHito,
    required String idTour,
    required String title,
    required String description,
    required String closingNote,
    HitoLocationDraft? location,
  }) async {
    updates.add({
      'idHito': idHito,
      'idTour': idTour,
      'title': title,
      'description': description,
      'closingNote': closingNote,
    });
    detail.titulo = title;
    detail.descripcion = description;
    detail.notaCierre = closingNote;
  }

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String passenger,
    String tour,
  ) async => Responseimagepassenger(image: '');
}

class _DetailLocationService extends LocationService {
  @override
  Future<void> initializeForCoordinatorSession() async {}
}

void main() {
  final image = base64Encode(TileProvider.transparentImage);
  late DetailHitoList detail;

  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    detail = DetailHitoList(
      titulo: 'Llegada al hotel',
      descripcion: 'El grupo llegó al hotel de ejemplo.',
      ubicacion: 'Destino ficticio',
      notaCierre: 'Todos reunidos en el punto de encuentro.',
      fecha: '05/11/2026',
      hora: '18:30',
      images: [image, image],
    );
    addTearDown(() {
      HttpOverrides.global = previous;
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
    });
  });

  void phone(WidgetTester tester, {double width = 393, double height = 852}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder field(String key) => find.byKey(ValueKey(key));
  final save = find.byKey(const ValueKey('hito-edit-save'));
  final cancel = find.byKey(const ValueKey('hito-edit-cancel'));

  Future<void> openEditor(
    WidgetTester tester, {
    required _Save onSave,
    ValueChanged<bool?>? onReturned,
    double textScale = 1,
    double keyboardHeight = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  final result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    enableDrag: false,
                    isDismissible: false,
                    builder: (_) =>
                        TripHitoEditSheet(detail: detail, onSave: onSave),
                  );
                  onReturned?.call(result);
                },
                child: const Text('Abrir edición'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir edición'));
    await tester.pumpAndSettle();
  }

  TextFormField formField(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(field(key));

  Future<void> tapSave(WidgetTester tester, {bool settle = true}) async {
    await tester.ensureVisible(save);
    await tester.tap(save);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets(
    'precarga el contenido y cancelar descarta sin guardar ni alterar el registro',
    (tester) async {
      phone(tester);
      final before = jsonEncode(detail.toJson());
      var saves = 0;
      bool? returned;
      await openEditor(
        tester,
        onSave: (_, __, ___) async {
          saves++;
        },
        onReturned: (value) => returned = value,
      );
      expect(
        formField(tester, 'hito-edit-title').controller!.text,
        detail.titulo,
      );
      expect(
        formField(tester, 'hito-edit-description').controller!.text,
        detail.descripcion,
      );
      expect(
        formField(tester, 'hito-edit-closing').controller!.text,
        detail.notaCierre,
      );
      await tester.enterText(
        field('hito-edit-title'),
        'Cambio que se descarta',
      );
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoEditSheet), findsNothing);
      expect(returned, isNot(true));
      expect(saves, 0);
      expect(jsonEncode(detail.toJson()), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('título y descripción vacíos o de espacios no se envían', (
    tester,
  ) async {
    phone(tester);
    var saves = 0;
    await openEditor(
      tester,
      onSave: (_, __, ___) async {
        saves++;
      },
    );
    await tester.enterText(field('hito-edit-title'), '   ');
    await tester.enterText(field('hito-edit-description'), '   ');
    await tapSave(tester);
    expect(saves, 0);
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    expect(find.byType(TripHitoEditSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'una descripción existente mayor a 140 no se recorta ni se guarda silenciosamente',
    (tester) async {
      phone(tester);
      detail.descripcion = List.filled(141, 'a').join();
      var saves = 0;
      await openEditor(
        tester,
        onSave: (_, __, ___) async {
          saves++;
        },
      );
      expect(
        formField(tester, 'hito-edit-description').controller!.text,
        detail.descripcion,
      );
      await tapSave(tester);
      expect(saves, 0);
      expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
      expect(detail.descripcion!.length, 141);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'contador y límite Unicode coinciden con las 140 unidades del servidor',
    (tester) async {
      phone(tester);
      final savedDescriptions = <String>[];
      await openEditor(
        tester,
        onSave: (_, description, __) async {
          savedDescriptions.add(description);
        },
      );
      final tooLong = List.filled(71, '🚌').join();
      await tester.enterText(field('hito-edit-description'), tooLong);
      await tester.pump();
      expect(find.text('142 / 140'), findsOneWidget);
      await tapSave(tester);
      expect(savedDescriptions, isEmpty);
      expect(find.text('Usa hasta 140 caracteres.'), findsOneWidget);
      final valid = List.filled(70, '🚌').join();
      await tester.enterText(field('hito-edit-description'), ' $valid ');
      await tester.pump();
      expect(find.text('140 / 140'), findsOneWidget);
      await tapSave(tester);
      expect(savedDescriptions, [valid]);
      expect(find.byType(TripHitoEditSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'título y nota existentes de 256 caracteres se conservan y no se guardan',
    (tester) async {
      phone(tester);
      detail.titulo = List.filled(256, 'T').join();
      detail.notaCierre = List.filled(256, 'N').join();
      var saves = 0;
      await openEditor(
        tester,
        onSave: (_, __, ___) async {
          saves++;
        },
      );
      expect(
        formField(tester, 'hito-edit-title').controller!.text,
        detail.titulo,
      );
      expect(
        formField(tester, 'hito-edit-closing').controller!.text,
        detail.notaCierre,
      );
      await tapSave(tester);
      expect(saves, 0);
      expect(find.text('Usa hasta 255 caracteres.'), findsNWidgets(2));
      expect(detail.titulo!.length, 256);
      expect(detail.notaCierre!.length, 256);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'título y nota cuentan puntos Unicode y aceptan exactamente 255',
    (tester) async {
      phone(tester);
      final saved = <List<String>>[];
      await openEditor(
        tester,
        onSave: (title, _, note) async {
          saved.add([title, note]);
        },
      );
      final tooLong = List.filled(128, 'a\u0301').join();
      await tester.enterText(field('hito-edit-title'), tooLong);
      await tester.enterText(field('hito-edit-closing'), tooLong);
      await tester.pump();
      expect(find.text('256 / 255'), findsNWidgets(2));
      await tapSave(tester);
      expect(saved, isEmpty);
      final valid = List.filled(255, '🚌').join();
      await tester.enterText(field('hito-edit-title'), valid);
      await tester.enterText(field('hito-edit-closing'), valid);
      await tester.pump();
      expect(find.text('255 / 255'), findsNWidgets(2));
      await tapSave(tester);
      expect(saved, [
        [valid, valid],
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('éxito impide otro envío antes del frame que cierra la hoja', (
    tester,
  ) async {
    phone(tester);
    var saves = 0;
    await openEditor(
      tester,
      onSave: (_, __, ___) async {
        saves++;
      },
    );
    final submit = tester.widget<FilledButton>(save).onPressed!;
    submit();
    await tester.idle();
    expect(saves, 1);
    // An old tap callback must not resubmit between completion and navigation.
    submit();
    await tester.idle();
    expect(saves, 1);
    await tester.pumpAndSettle();
    expect(find.byType(TripHitoEditSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guardar emite solo los tres textos editables y devuelve éxito', (
    tester,
  ) async {
    phone(tester);
    final before = jsonEncode(detail.toJson());
    final calls = <List<String>>[];
    bool? returned;
    await openEditor(
      tester,
      onSave: (title, description, note) async {
        calls.add([title, description, note]);
      },
      onReturned: (value) => returned = value,
    );
    await tester.enterText(field('hito-edit-title'), 'Título actualizado');
    await tester.enterText(
      field('hito-edit-description'),
      'Descripción actualizada',
    );
    await tester.enterText(field('hito-edit-closing'), '');
    await tapSave(tester);
    expect(calls, [
      ['Título actualizado', 'Descripción actualizada', ''],
    ]);
    expect(returned, isTrue);
    expect(find.byType(TripHitoEditSheet), findsNothing);
    expect(jsonEncode(detail.toJson()), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guardado pendiente evita doble envío y bloquea campos, cancelar y atrás',
    (tester) async {
      phone(tester);
      final request = Completer<void>();
      var saves = 0;
      await openEditor(
        tester,
        onSave: (_, __, ___) {
          saves++;
          return request.future;
        },
      );
      await tapSave(tester, settle: false);
      expect(saves, 1);
      expect(formField(tester, 'hito-edit-title').enabled, isFalse);
      expect(formField(tester, 'hito-edit-description').enabled, isFalse);
      expect(formField(tester, 'hito-edit-closing').enabled, isFalse);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(save);
      await tester.pump();
      await tester.ensureVisible(cancel);
      expect(tester.widget<TextButton>(cancel).onPressed, isNull);
      await tester.tap(cancel);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(TripHitoEditSheet), findsOneWidget);
      expect(saves, 1);
      request.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoEditSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'error de guardado conserva cambios, oculta el detalle técnico y permite reintentar',
    (tester) async {
      phone(tester);
      var attempts = 0;
      await openEditor(
        tester,
        onSave: (_, __, ___) async {
          attempts++;
          if (attempts == 1) throw StateError('PAYLOAD_TECNICO_NO_VISIBLE');
        },
      );
      await tester.enterText(
        field('hito-edit-title'),
        'Edición que se conserva',
      );
      await tapSave(tester);
      expect(attempts, 1);
      expect(
        find.textContaining('No pudimos guardar los cambios'),
        findsOneWidget,
      );
      expect(find.byType(TripHitoEditSheet), findsOneWidget);
      expect(
        formField(tester, 'hito-edit-title').controller!.text,
        'Edición que se conserva',
      );
      expect(find.textContaining('PAYLOAD_TECNICO_NO_VISIBLE'), findsNothing);
      expect(formField(tester, 'hito-edit-title').enabled, isNot(false));
      await tapSave(tester);
      expect(attempts, 2);
      expect(find.byType(TripHitoEditSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'formulario a 320 px con texto ampliado y teclado conserva acciones utilizables',
    (tester) async {
      phone(tester, width: 320, height: 740);
      await openEditor(
        tester,
        onSave: (_, __, ___) async {},
        textScale: 1.6,
        keyboardHeight: 280,
      );
      await tester.ensureVisible(field('hito-edit-closing'));
      await tester.enterText(field('hito-edit-closing'), 'Nota de prueba');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoEditSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fotos grandes redondeadas abren la galería completa desde su índice',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TripHitoContent(detail: detail)),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('trip-content-photo-0'));
      expect(tester.getSize(first).width, greaterThan(320));
      expect(tester.getSize(first).width, lessThanOrEqualTo(393));
      expect(tester.getSize(first).height, greaterThan(200));
      final surface = tester.widget<Material>(
        find.ancestor(of: first, matching: find.byType(Material)).first,
      );
      expect(surface.clipBehavior, isNot(Clip.none));
      expect(
        surface.borderRadius!.resolve(TextDirection.ltr).topLeft.x,
        greaterThan(0),
      );
      final second = find.byKey(const ValueKey('trip-content-photo-1'));
      await tester.scrollUntilVisible(
        second,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      expect(find.text('2 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Foto anterior'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar fotos'));
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoContent), findsOneWidget);
      expect(second.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sin fotos y una imagen inválida muestran estados honestos sin desbordes',
    (tester) async {
      phone(tester, width: 320, height: 740);
      detail.images = [];
      detail.ubicacion = 'PlatformException(IO_ERROR, fallo ficticio)';
      detail.missingImageCount = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TripHitoContent(detail: detail)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TripPhoto), findsNothing);
      expect(find.text('Una foto no está disponible.'), findsOneWidget);
      expect(find.text('Ubicación no disponible'), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
      detail.images = ['base64-invalido'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TripHitoContent(detail: detail)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.hide_image_outlined), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trip-content-photo-0')));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      expect(find.byIcon(Icons.hide_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'acciones solo aparecen para coordinador autorizado; ambos roles usan galería',
    (tester) async {
      phone(tester);
      final location = _DetailLocationService();
      final provider = _DetailProvider(detail);
      addTearDown(location.dispose);
      addTearDown(provider.dispose);
      final login = TourSales.fromCoordinatorTour(
        coordinator: LabFixtures.coordinator,
        tour: LabFixtures.tour,
      );
      for (final allowed in [false, true]) {
        await tester.pumpWidget(
          ChangeNotifierProvider<LocationService>.value(
            value: location,
            child: MaterialApp(
              home: DetalleBitacoraCoordScreen(
                login: login,
                idHito: '1',
                canModify: allowed,
                provider: provider,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Editar'), allowed ? findsOneWidget : findsNothing);
        expect(
          find.text('Eliminar hito'),
          allowed ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('trip-content-photo-0')));
        await tester.pumpAndSettle();
        expect(find.byType(TripPhotoGallery), findsOneWidget);
        await tester.tap(find.byTooltip('Foto siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('2 de 2'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar fotos'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(
        MaterialApp(
          home: DetalleBitacoraFatherScreen(
            login: LabFixtures.passenger,
            idHito: '1',
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Eliminar hito'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('trip-content-photo-0')));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      await tester.tap(find.byTooltip('Foto siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coordinador guarda mediante provider, recarga y conserva fecha y fotografías',
    (tester) async {
      phone(tester);
      final location = _DetailLocationService();
      final provider = _DetailProvider(detail);
      addTearDown(location.dispose);
      addTearDown(provider.dispose);
      final photoSnapshot = List.of(detail.images);
      await tester.pumpWidget(
        ChangeNotifierProvider<LocationService>.value(
          value: location,
          child: MaterialApp(
            home: DetalleBitacoraCoordScreen(
              login: TourSales.fromCoordinatorTour(
                coordinator: LabFixtures.coordinator,
                tour: LabFixtures.tour,
              ),
              idHito: '1',
              canModify: true,
              provider: provider,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        field('hito-edit-title'),
        'Nueva información ficticia',
      );
      await tapSave(tester);
      expect(provider.updates, [
        {
          'idHito': '1',
          'idTour': LabFixtures.tour.tourId.toString(),
          'title': 'Nueva información ficticia',
          'description': detail.descripcion!,
          'closingNote': detail.notaCierre!,
        },
      ]);
      expect(provider.calls, 2);
      expect(find.text('Nueva información ficticia'), findsOneWidget);
      expect(find.text('Cambios guardados'), findsOneWidget);
      expect(detail.fecha, '05/11/2026');
      expect(detail.hora, '18:30');
      expect(detail.ubicacion, 'Destino ficticio');
      expect(detail.images, photoSnapshot);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detalle fallido permite repetir y recuperar la carga en ambos roles',
    (tester) async {
      phone(tester);
      final location = _DetailLocationService();
      addTearDown(location.dispose);
      for (final coordinator in [true, false]) {
        final provider = _DetailProvider(detail)..fail = true;
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<LocationService>.value(
            value: location,
            child: MaterialApp(
              home: coordinator
                  ? DetalleBitacoraCoordScreen(
                      login: TourSales.fromCoordinatorTour(
                        coordinator: LabFixtures.coordinator,
                        tour: LabFixtures.tour,
                      ),
                      idHito: '1',
                      canModify: false,
                      provider: provider,
                    )
                  : DetalleBitacoraFatherScreen(
                      login: LabFixtures.passenger,
                      idHito: '1',
                      provider: provider,
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('PAYLOAD_TECNICO_NO_VISIBLE'), findsNothing);
        expect(find.text('Reintentar'), findsOneWidget);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(provider.calls, 2);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(tester.takeException(), isNull);
        provider.fail = false;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(provider.calls, 3);
        expect(find.byType(TripHitoContent), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
}
