import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/maps/trip_binnacle_timeline.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';

void main() {
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    SharedPreferences.setMockInitialValues({});
    LabFixtures.reset();
    final original = LabFixtures.hitos.first;
    LabFixtures.hitos = [
      for (var i = 0; i < 8; i++)
        ConsolidatedTourSalesDTO.fromJson({
          ...original.toJson(),
          'binnacleDetailId': i + 1,
          'binnacleTitulo': 'Hito ${i + 1} de prueba',
          'binnacleFecha': '05/11/2026',
          'binnacleHora': '${17 - i}:00',
          'binnacleDescripcion':
              'Una descripción ficticia para consultar el resumen del recorrido.',
        }),
    ];
    final image = base64Encode(TileProvider.transparentImage);
    LabFixtures.photos[1] = [image, image, image];
    addTearDown(() {
      HttpOverrides.global = previous;
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
    });
  });

  Finder card(int id) => find.byKey(ValueKey('timeline-card-$id'));
  Finder within(int id, String key) =>
      find.descendant(of: card(id), matching: find.byKey(ValueKey(key)));
  Finder parentScroll() => find
      .descendant(
        of: find.byType(TripBinnacleTimeline),
        matching: find.byType(Scrollable),
      )
      .first;
  ScrollPosition listPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(parentScroll()).position;

  Future<void> show(
    WidgetTester tester, {
    double width = 393,
    double height = 852,
    double textScale = 1,
    bool showAuthor = false,
    int tourId = 1,
    bool pilo = false,
    Future<void> Function(TripMapEntry)? onOpenDetail,
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
          body: TripBinnacleTimeline(
            tourId: tourId,
            showAuthor: showAuthor,
            onOpenDetail: onOpenDetail ?? (_) async {},
            familyHeader: pilo ? (_) => const Text('Bitácora') : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'un toque en cuerpo, foto o círculo alterna una sola vez sin rayita ni galería',
    (tester) async {
      await show(tester);
      final compactHeight = tester.getSize(card(1)).height;
      expect(within(1, 'trip-hito-handle'), findsNothing);
      expect(
        tester.getSize(within(1, 'trip-timeline-toggle')),
        const Size.square(48),
      );
      expect(
        find.descendant(of: card(1), matching: find.byTooltip('Ampliar hito')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: card(1), matching: find.text('Hito 1 de prueba')),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, greaterThan(compactHeight));
      expect(
        find.descendant(of: card(1), matching: find.byTooltip('Reducir hito')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: card(1), matching: find.text('Hito 1 de prueba')),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));

      await tester.tap(within(1, 'trip-photo-gallery-1'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, greaterThan(compactHeight));
      await tester.tap(within(1, 'trip-inline-photo-0'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      expect(find.byType(TripPhotoGallery), findsNothing);
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, greaterThan(compactHeight));
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'arrastrar verticalmente cuerpo, foto y botón desplaza la lista sin cambiar estado',
    (tester) async {
      await show(tester);
      final compactHeight = tester.getSize(card(1)).height;
      await tester.drag(within(1, 'trip-hito-card-tap'), const Offset(0, -90));
      await tester.pumpAndSettle();
      expect(listPosition(tester).pixels, greaterThan(20));
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      listPosition(tester).jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      final expandedHeight = tester.getSize(card(1)).height;
      for (final target in [
        'trip-hito-card-tap',
        'trip-inline-photos',
        'trip-timeline-toggle',
      ]) {
        listPosition(tester).jumpTo(0);
        await tester.pumpAndSettle();
        await tester.drag(within(1, target), const Offset(0, -90));
        await tester.pumpAndSettle();
        expect(listPosition(tester).pixels, greaterThan(20), reason: target);
        expect(
          tester.getSize(card(1)).height,
          closeTo(expandedHeight, .1),
          reason: target,
        );
      }
      expect(
        find.descendant(
          of: card(1),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el deslizamiento horizontal recorre fotos y tocar la foto contrae',
    (tester) async {
      await show(tester);
      final compactHeight = tester.getSize(card(1)).height;
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      final expandedHeight = tester.getSize(card(1)).height;
      final pager = within(1, 'trip-inline-photos');
      await tester.drag(pager, Offset(-tester.getSize(pager).width * .9, 0));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: card(1), matching: find.text('2/3')),
        findsOneWidget,
      );
      expect(tester.getSize(card(1)).height, closeTo(expandedHeight, .1));
      expect(listPosition(tester).pixels, closeTo(0, .1));
      await tester.tap(within(1, 'trip-inline-photo-1'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ver más ejecuta su acción independiente sin alternar ni ocultar la tarjeta',
    (tester) async {
      final opened = <int>[];
      await show(tester, onOpenDetail: (entry) async => opened.add(entry.id));
      final compactHeight = tester.getSize(card(1)).height;
      await tester.tap(within(1, 'trip-timeline-detail'));
      await tester.pumpAndSettle();
      expect(opened, [1]);
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      final expandedHeight = tester.getSize(card(1)).height;
      await tester.tap(within(1, 'trip-timeline-detail'));
      await tester.pumpAndSettle();
      expect(opened, [1, 1]);
      expect(tester.getSize(card(1)).height, closeTo(expandedHeight, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320 px y texto1.6 conservan acciones visibles y un resumen sin overflow',
    (tester) async {
      LabFixtures.hitos[0] = ConsolidatedTourSalesDTO.fromJson({
        ...LabFixtures.hitos[0].toJson(),
        'binnacleTitulo':
            'Llegada del grupo al punto de encuentro después de un recorrido muy extenso',
        'binnacleUbicacion':
            'Entrada principal del lugar de encuentro acordado con el coordinador',
        'binnacleDescripcion': List.filled(
          30,
          'Relato largo de prueba que continúa en el detalle completo.',
        ).join(' '),
      });
      await show(
        tester,
        width: 320,
        height: 740,
        textScale: 1.6,
        showAuthor: true,
      );
      for (final expand in [false, true]) {
        if (expand) {
          await tester.tap(within(1, 'trip-timeline-toggle'));
          await tester.pumpAndSettle();
        }
        final bounds = tester.getRect(card(1));
        final actionBounds = tester.getRect(within(1, 'trip-timeline-detail'));
        final toggleBounds = tester.getRect(within(1, 'trip-timeline-toggle'));
        expect(bounds.contains(actionBounds.topLeft), isTrue);
        expect(
          bounds.contains(actionBounds.bottomRight - const Offset(.1, .1)),
          isTrue,
        );
        expect(
          bounds.contains(toggleBounds.bottomRight - const Offset(.1, .1)),
          isTrue,
        );
        expect(actionBounds.height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      }
      final preview = tester.widget<Text>(
        within(1, 'trip-timeline-description'),
      );
      expect(preview.maxLines, greaterThanOrEqualTo(1));
      expect(preview.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(within(1, 'trip-hito-sheet')).height,
        lessThanOrEqualTo(740 / 3),
      );
    },
  );
  testWidgets(
    '320×568 con texto1.6 y voz conserva título y acciones sin recortarlos',
    (tester) async {
      LabFixtures.hitos[0] = ConsolidatedTourSalesDTO.fromJson({
        ...LabFixtures.hitos[0].toJson(),
        'binnacleTitulo': 'Llegada',
        'binnacleUbicacion': 'Hotel',
        'voiceNote': {
          'id': 'nota-ficticia-pg018',
          'durationMs': 6900,
          'sizeBytes': 220844,
          'contentType': 'audio/wav',
        },
      });
      await show(
        tester,
        width: 320,
        height: 568,
        textScale: 1.6,
        showAuthor: true,
      );
      for (final expanded in [false, true]) {
        if (expanded) {
          await tester.tap(within(1, 'trip-timeline-toggle'));
          await tester.pumpAndSettle();
        }
        final bounds = tester.getRect(card(1));
        final title = find.descendant(
          of: card(1),
          matching: find.text('Llegada'),
        );
        final titleBounds = tester.getRect(title);
        final voiceBounds = tester.getRect(within(1, 'voice-play'));
        expect(titleBounds.height, greaterThanOrEqualTo(17 * 1.6));
        expect(titleBounds.bottom, lessThanOrEqualTo(voiceBounds.top));
        expect(
          tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
          isFalse,
        );
        for (final key in [
          'trip-timeline-detail',
          'trip-timeline-toggle',
          'voice-play',
        ]) {
          final action = tester.getRect(within(1, key));
          expect(bounds.contains(action.topLeft), isTrue, reason: key);
          expect(
            bounds.contains(action.bottomRight - const Offset(.1, .1)),
            isTrue,
            reason: key,
          );
          expect(action.height, greaterThanOrEqualTo(44), reason: key);
        }
        expect(bounds.height, greaterThan(568 / 3));
        expect(tester.takeException(), isNull);
      }
      final expandedHeight = tester.getSize(card(1)).height;
      await tester.drag(within(1, 'trip-hito-card-tap'), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(listPosition(tester).pixels, greaterThan(20));
      expect(tester.getSize(card(1)).height, closeTo(expandedHeight, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'descripción de140 caracteres ocupa todo el ancho debajo de la foto y cabe completa',
    (tester) async {
      const story =
          'El grupo llegó al hotel y compartió una tarde tranquila. Luego se reunieron para revisar los planes del día siguiente y descansar con calma.';
      expect(story.length, 140);
      LabFixtures.hitos[0] = ConsolidatedTourSalesDTO.fromJson({
        ...LabFixtures.hitos[0].toJson(),
        'binnacleDescripcion': story,
      });
      // This viewport gives the recorded text enough room even with Flutter's
      // wide test font; no arbitrary three-line cap should hide the remainder.
      await show(tester, width: 430, height: 932, showAuthor: true);
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      final header = tester.getRect(within(1, 'trip-timeline-header'));
      final photos = tester.getRect(within(1, 'trip-inline-photos'));
      final description = within(1, 'trip-timeline-description');
      final bounds = tester.getRect(description);
      expect(photos.bottom, lessThanOrEqualTo(header.bottom + .1));
      expect(bounds.top, greaterThanOrEqualTo(header.bottom + 7.9));
      expect(bounds.left, closeTo(header.left, .1));
      expect(bounds.width, closeTo(header.width, .1));
      expect(tester.widget<Text>(description).maxLines, isNull);
      expect(
        tester.renderObject<RenderParagraph>(description).didExceedMaxLines,
        isFalse,
      );
      expect(
        bounds.bottom,
        lessThanOrEqualTo(
          tester.getRect(within(1, 'trip-timeline-detail')).top + .1,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'abrir otra tarjeta contrae la anterior y tocar la abierta deja todas compactas',
    (tester) async {
      await show(tester);
      final compactHeight = tester.getSize(card(1)).height;
      final secondCompactHeight = tester.getSize(card(2)).height;
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, greaterThan(compactHeight));
      await tester.tap(within(2, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      expect(tester.getSize(card(2)).height, greaterThan(secondCompactHeight));
      expect(find.byTooltip('Reducir hito'), findsOneWidget);
      await tester.tap(
        find.descendant(of: card(2), matching: find.text('Hito 2 de prueba')),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reducir hito'), findsNothing);
      expect(tester.getSize(card(2)).height, closeTo(secondCompactHeight, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pilo alterna una sola tarjeta y recorre las fotos dentro del hito',
    (tester) async {
      final opened = <int>[];
      await show(
        tester,
        pilo: true,
        height: 920,
        onOpenDetail: (entry) async => opened.add(entry.id),
      );

      Finder title(int id) => find.descendant(
        of: card(id),
        matching: find.text('Hito $id de prueba'),
      );
      Finder pager(int id) => within(id, 'trip-inline-photos');

      Future<void> reveal(Finder target) async {
        await Scrollable.ensureVisible(tester.element(target), alignment: .25);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
      }

      final compactHeight = tester.getSize(card(1)).height;
      Rect relativeToCard(Finder child) =>
          tester.getRect(child).shift(-tester.getTopLeft(card(1)));
      final titlePosition = relativeToCard(title(1));
      final photoPosition = relativeToCard(pager(1));
      expect(within(1, 'trip-timeline-description'), findsNothing);

      await tester.tap(title(1));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, greaterThan(compactHeight));
      expect(relativeToCard(title(1)).topLeft, titlePosition.topLeft);
      final expandedPhoto = relativeToCard(pager(1));
      expect(expandedPhoto.width, greaterThan(photoPosition.width * 2));
      expect(expandedPhoto.height, inInclusiveRange(180, 220));
      expect(expandedPhoto.top, greaterThan(titlePosition.bottom));
      expect(within(1, 'trip-timeline-description'), findsOneWidget);
      expect(find.byTooltip('Reducir hito'), findsOneWidget);

      await reveal(pager(1));
      await tester.drag(
        pager(1),
        Offset(-tester.getSize(pager(1)).width * .9, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(opened, isEmpty);

      await tester.tap(within(1, 'trip-inline-photo-1'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      expect(relativeToCard(pager(1)), photoPosition);
      expect(find.text('2/3'), findsOneWidget);
      expect(within(1, 'trip-timeline-description'), findsNothing);
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(opened, isEmpty);

      await reveal(title(1));
      await tester.tap(title(1));
      await tester.pumpAndSettle();
      await reveal(title(2));
      await tester.tap(title(2));
      await tester.pumpAndSettle();
      expect(within(1, 'trip-timeline-description'), findsNothing);
      expect(
        find.descendant(of: card(2), matching: find.byTooltip('Reducir hito')),
        findsOneWidget,
      );

      final detail = within(2, 'trip-timeline-detail');
      await reveal(detail);
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(opened, [2]);
      expect(find.byTooltip('Reducir hito'), findsOneWidget);

      await reveal(title(2));
      await tester.tap(title(2));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reducir hito'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'acciones semánticas respetan el acordeón y reconstruir no reinicia las fotos',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await show(tester);
        Semantics sheetSemantics(int id) => tester.widget<Semantics>(
          find.descendant(
            of: card(id),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  (widget.properties.value == 'Compacta' ||
                      widget.properties.value == 'Ampliada'),
            ),
          ),
        );
        sheetSemantics(1).properties.onIncrease!();
        await tester.pumpAndSettle();
        final pager = within(1, 'trip-inline-photos');
        await tester.drag(pager, Offset(-tester.getSize(pager).width * .9, 0));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: card(1), matching: find.text('2/3')),
          findsOneWidget,
        );
        await show(tester, showAuthor: true);
        expect(sheetSemantics(1).properties.value, 'Ampliada');
        expect(
          find.descendant(of: card(1), matching: find.text('2/3')),
          findsOneWidget,
        );
        sheetSemantics(2).properties.onIncrease!();
        await tester.pumpAndSettle();
        expect(sheetSemantics(1).properties.value, 'Compacta');
        expect(sheetSemantics(2).properties.value, 'Ampliada');
        sheetSemantics(2).properties.onDecrease!();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Reducir hito'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('virtualizar una fila conserva la única expansión por ID', (
    tester,
  ) async {
    await show(tester);
    final compactHeight = tester.getSize(card(1)).height;
    await tester.tap(within(1, 'trip-timeline-toggle'));
    await tester.pumpAndSettle();
    final expandedHeight = tester.getSize(card(1)).height;
    listPosition(tester).jumpTo(listPosition(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    expect(card(1), findsNothing);
    listPosition(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getSize(card(1)).height, closeTo(expandedHeight, .1));
    listPosition(tester).jumpTo(listPosition(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.ensureVisible(within(8, 'trip-timeline-toggle'));
    await tester.tap(within(8, 'trip-timeline-toggle'));
    await tester.pumpAndSettle();
    expect(tester.getSize(card(8)).height, closeTo(expandedHeight, .1));
    listPosition(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
    listPosition(tester).jumpTo(listPosition(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getSize(card(8)).height, closeTo(expandedHeight, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refrescar conserva expansión y desaparecer o cambiar de gira la limpia',
    (tester) async {
      await show(tester);
      final compactHeight = tester.getSize(card(1)).height;
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      final expandedHeight = tester.getSize(card(1)).height;
      await tester.tap(find.byTooltip('Actualizar bitácora'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(expandedHeight, .1));
      final rows = List<ConsolidatedTourSalesDTO>.of(LabFixtures.hitos);
      LabFixtures.hitos.removeWhere((entry) => entry.binnacleDetailId == 1);
      await tester.tap(find.byTooltip('Actualizar bitácora'));
      await tester.pumpAndSettle();
      expect(card(1), findsNothing);
      LabFixtures.hitos = rows;
      await tester.tap(find.byTooltip('Actualizar bitácora'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      await tester.tap(within(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      await show(tester, tourId: 2);
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      expect(find.byTooltip('Reducir hito'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
