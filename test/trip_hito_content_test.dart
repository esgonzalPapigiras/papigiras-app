import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/maps/trip_hito_content.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';

void main() {
  final image = base64Encode(TileProvider.transparentImage);

  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    addTearDown(() => HttpOverrides.global = previous);
  });

  Future<void> show(
    WidgetTester tester,
    DetailHitoList detail, {
    double width = 393,
    double height = 852,
    double textScale = 1,
    Widget? actions,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: TripHitoContent(detail: detail, actions: actions),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder photo(int index) => find.byKey(ValueKey('trip-content-photo-$index'));
  Finder contentScroll() => find
      .descendant(
        of: find.byType(TripHitoContent),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets(
    'fotos grandes abren la galería en su índice y conservan el recorrido',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await show(
          tester,
          DetailHitoList(
            titulo: 'Recorrido junto al lago',
            fecha: '05/11/2026',
            hora: '14:23:19',
            ubicacion: 'Mirador de ejemplo',
            descripcion: 'El grupo compartió una tarde de paseo.',
            images: [image, image],
          ),
        );
        expect(find.text('5 nov 2026 · 14:23'), findsOneWidget);
        final firstSize = tester.getSize(photo(0));
        expect(firstSize.width, closeTo(393 - 40, .1));
        expect(firstSize.width / firstSize.height, closeTo(1.5, .01));
        expect(find.textContaining('Eliminar'), findsNothing);
        expect(find.textContaining('Editar'), findsNothing);
        await tester.scrollUntilVisible(
          photo(1),
          250,
          scrollable: contentScroll(),
        );
        final scroll = tester
            .state<ScrollableState>(contentScroll())
            .position
            .pixels;
        expect(find.bySemanticsLabel('Abrir foto 2 de 2'), findsOneWidget);
        await tester.tap(photo(1));
        await tester.pumpAndSettle();
        final gallery = tester.widget<TripPhotoGallery>(
          find.byType(TripPhotoGallery),
        );
        expect(gallery.initialIndex, 1);
        expect(gallery.images, [image, image]);
        expect(find.text('2 de 2'), findsOneWidget);
        await tester.tap(find.byTooltip('Foto anterior'));
        await tester.pumpAndSettle();
        expect(find.text('1 de 2'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar fotos'));
        await tester.pumpAndSettle();
        expect(find.byType(TripPhotoGallery), findsNothing);
        expect(
          tester.state<ScrollableState>(contentScroll()).position.pixels,
          closeTo(scroll, .1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    '320 px y texto ampliado mantienen título, fotos y contenido sin desbordarse',
    (tester) async {
      var actionCalls = 0;
      const description =
          'Una descripción extensa de ejemplo para leer los detalles del encuentro y el recorrido del grupo durante esta jornada.';
      const note =
          'El próximo encuentro será en el punto acordado con el coordinador.';
      await show(
        tester,
        DetailHitoList(
          titulo:
              'Encuentro del grupo en el mirador principal después del recorrido',
          fecha: '2026-11-05',
          ubicacion:
              'Entrada principal del mirador de ejemplo, junto al punto de reunión',
          descripcion: description,
          notaCierre: note,
          images: [image, image],
        ),
        width: 320,
        height: 740,
        textScale: 1.6,
        actions: TextButton(
          onPressed: () => actionCalls++,
          child: const Text('Acción autorizada'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('5 nov 2026'), findsOneWidget);
      expect(find.textContaining('00:00'), findsNothing);
      await tester.ensureVisible(find.text('Acción autorizada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acción autorizada'));
      expect(actionCalls, 1);
      await tester.scrollUntilVisible(
        photo(0),
        240,
        scrollable: contentScroll(),
      );
      expect(tester.getSize(photo(0)).width, closeTo(280, .1));
      await tester.scrollUntilVisible(
        find.text(note),
        300,
        scrollable: contentScroll(),
      );
      expect(find.text(note), findsOneWidget);
      expect(find.text(description), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sin fotos no reserva una galería vacía y distingue datos temporales ausentes',
    (tester) async {
      await show(
        tester,
        DetailHitoList(
          titulo: 'Hito de ejemplo',
          fecha: '2026-11-05',
          descripcion: 'Registro sin fotografías.',
        ),
      );
      expect(find.byType(TripPhoto), findsNothing);
      expect(find.byKey(const ValueKey('trip-content-location')), findsNothing);
      expect(
        find.byKey(const ValueKey('trip-content-missing-photos')),
        findsNothing,
      );
      expect(find.text('5 nov 2026'), findsOneWidget);
      expect(find.textContaining('00:00'), findsNothing);
      await show(
        tester,
        DetailHitoList(
          titulo: 'Fecha por confirmar',
          fecha: '2026-02-31',
          hora: '09:15',
        ),
      );
      expect(find.text('Fecha sin confirmar · 09:15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fotos faltantes, base64 inválido y errores históricos tienen un fallback legible',
    (tester) async {
      const storedLocation =
          'PlatformException(IO_ERROR, geocoding failed, null, null)';
      final detail = DetailHitoList(
        titulo: 'Registro de ejemplo',
        fecha: '2026-11-05T18:20:00-03:00',
        ubicacion: storedLocation,
        images: ['imagen-no-decodificable'],
        missingImageCount: 2,
      );
      await show(tester, detail);
      expect(find.text('5 nov 2026 · 18:20'), findsOneWidget);
      expect(find.text(storedLocation), findsNothing);
      expect(find.text('Ubicación no disponible'), findsOneWidget);
      expect(find.text('2 fotos no están disponibles.'), findsOneWidget);
      expect(find.byIcon(Icons.hide_image_outlined), findsOneWidget);
      expect(detail.ubicacion, storedLocation);
      expect(detail.images, ['imagen-no-decodificable']);
      await tester.tap(photo(0));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      expect(find.byIcon(Icons.hide_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tablet limita ancho y construye las fotos restantes según el scroll',
    (tester) async {
      await show(
        tester,
        DetailHitoList(
          titulo: 'Álbum de ejemplo',
          fecha: '05/11/2026',
          images: List.filled(20, image),
        ),
        width: 1024,
        height: 900,
      );
      expect(tester.getSize(photo(0)).width, closeTo(660, .1));
      expect(find.byType(TripPhoto).evaluate().length, lessThan(20));
      expect(photo(19), findsNothing);
      await tester.scrollUntilVisible(
        photo(19),
        600,
        maxScrolls: 30,
        scrollable: contentScroll(),
      );
      expect(photo(19), findsOneWidget);
      expect(find.byType(TripPhoto).evaluate().length, lessThan(20));
      await tester.tap(photo(19));
      await tester.pumpAndSettle();
      expect(find.text('20 de 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
