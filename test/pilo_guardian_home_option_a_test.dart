import 'support/visual_capture.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:papigiras_app/design/family_home.dart';
import 'package:papigiras_app/design/pilo_family_gallery_preview.dart';
import 'package:papigiras_app/design/pilo_trip_progress.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';
import 'pilo_family_gallery_preview_test.dart' show PreviewController, rows;
import 'support/ux_demo_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundary = GlobalKey();
  setUpAll(() async {
    await initializeDateFormatting('es');
    await Future.wait([
      (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
      (FontLoader(
        'Manjari',
      )..addFont(rootBundle.load('assets/fonts/Manjari-Regular.ttf'))).load(),
      (FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
          .load(),
    ]);
  });
  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['PILO_HOME_CAPTURE'] != '1') return;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await visualCaptureFile(
        'registro-local/PILO-APODERADO-INICIO-A/evidencia/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  for (final (size, scale) in [
    (const Size(402, 874), 1.0),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 3.0),
    (const Size(844, 390), 1.0),
  ]) {
    captureTest('Option A home, gallery and details usable $size / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PreviewController(rows(1))
        ..images = [uxLagoonPhoto, uxParkPhoto, uxCityPhoto];
      addTearDown(controller.dispose);
      var medical = 0;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => RepaintBoundary(
              key: boundary,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 48, bottom: 24),
                ),
                child: child!,
              ),
            ),
            home: FamilyNavigation(
              pilo: true,
              builders: {
                for (final section in FamilySection.values)
                  section: (context) {
                    final nav = FamilyNavigationScope.maybeOf(context)!;
                    return Scaffold(
                      body: section == FamilySection.home
                          ? SafeArea(
                              bottom: false,
                              child: FamilyHome(
                                showNavigation: false,
                                givenNames: 'SOFÍA ISABEL',
                                surnames: 'TORRES EJEMPLO',
                                rut: 'LAB-910011',
                                school: scale == 1
                                    ? 'COLEGIO HORIZONTE LAB'
                                    : 'COLEGIO DE DEMOSTRACIÓN CON NOMBRE MUY EXTENSO LAB',
                                course: '3° Medio B',
                                year: '2026',
                                departure: '2026-11-13',
                                returnDate: '2026-11-19',
                                tourCode: 'BRC26910001A',
                                avatar: const CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Color(0xFFD7ECE5),
                                  child: Text(
                                    'ST',
                                    style: TextStyle(
                                      color: Color(0xFF166357),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                map: const CustomPaint(painter: _MapFixture()),
                                mapStatus: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(20),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    child: Text(
                                      'Mapa de la gira',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                                latestHito: controller,
                                latestHitoTitle: () =>
                                    'Una tarde frente al lago',
                                latestHitoDate: () =>
                                    DateTime(2026, 11, 15, 16, 20),
                                galleryPreview: PiloFamilyGalleryPreview(
                                  controller: controller,
                                  onOpen: () =>
                                      nav.select(FamilySection.gallery),
                                ),
                                onMenu: () {},
                                onMedical: () => medical++,
                                onDiary: () => nav.select(FamilySection.diary),
                                onCrew: () => nav.select(FamilySection.crew),
                                onDocuments: () =>
                                    nav.select(FamilySection.documents),
                                onMap: () => nav.select(FamilySection.map),
                                onGallery: () =>
                                    nav.select(FamilySection.gallery),
                              ),
                            )
                          : Text('Destino ${section.name}'),
                    );
                  },
              },
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 450));
      });
      await tester.pumpAndSettle();
      // Thumbnail generation completes first; Image.memory then needs its own
      // asynchronous codec frame. Warm that exact provider before capturing.
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(image.image, boundary.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(3));
      for (final raw in tester.renderObjectList<RenderImage>(
        find.byType(RawImage),
      )) {
        expect(raw.image, isNotNull);
      }
      expect(tester.takeException(), isNull);
      if (scale == 1 && size.width == 402)
        await capture(tester, 'inicio-a-fixture');
      final map = find.byKey(const ValueKey('family-map-card'));
      expect(tester.getSize(map).height, lessThanOrEqualTo(190));
      final details = find.byKey(const ValueKey('family-trip-details'));
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Datos de la gira'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (scale == 1 && size.width == 402)
        await capture(tester, 'datos-gira-a-fixture');
      final documents = find.byKey(const ValueKey('family-action-documents'));
      await tester.ensureVisible(documents);
      await tester.pumpAndSettle();
      await tester.tap(documents);
      await tester.pumpAndSettle();
      expect(find.text('Destino documents'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('family-tab-home')));
      await tester.pumpAndSettle();
      final med = find.byKey(const ValueKey('family-medical'));
      await tester.ensureVisible(med);
      await tester.pumpAndSettle();
      await tester.tap(med);
      expect(medical, 1);
      final gallery = find.byKey(const ValueKey('family-gallery-open'));
      await tester.ensureVisible(gallery);
      await tester.pumpAndSettle();
      if (scale == 1 && size.width == 402)
        await capture(tester, 'inicio-a-fotos-fixture');
      await tester.tap(gallery);
      await tester.pumpAndSettle();
      expect(find.text('Destino gallery'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  captureTest(
    'dark trip summary preserves calendar dates and incomplete data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PiloTripProgress(
              departure: '2026-12-31T23:30:00-03:00',
              returnDate: '2027-01-02',
              now: () => DateTime(2027, 1, 1),
              summaryTitle: 'Tu gira',
              summarySubtitle: 'Colegio LAB',
            ),
          ),
        ),
      );
      expect(find.text('Día 2 de 3'), findsOneWidget);
      expect(find.text('31 dic. 2026'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        2 / 3,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PiloTripProgress(
              departure: '',
              returnDate: '',
              summaryTitle: 'Tu gira',
            ),
          ),
        ),
      );
      expect(find.text('Fechas por confirmar'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}

/// Deliberately illustrative, synthetic map surface for layout-only QA.
class _MapFixture extends CustomPainter {
  const _MapFixture();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8ECE9),
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * .4, -45, size.width, 140),
      Paint()..color = const Color(0xFFD3E2E5),
    );
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 8;
    for (var i = 0; i < 5; i++) {
      final x = i * 90.0;
      canvas.drawLine(Offset(x, -20), Offset(x + 65, size.height), road);
    }
    canvas.drawLine(Offset(0, size.height * .75), Offset(size.width, 30), road);
    for (final pos in [
      Offset(size.width * .3, size.height * .64),
      Offset(size.width * .68, size.height * .3),
    ]) {
      final path = Path()
        ..moveTo(pos.dx, pos.dy + 17)
        ..quadraticBezierTo(pos.dx - 24, pos.dy - 7, pos.dx - 6, pos.dy - 13)
        ..quadraticBezierTo(pos.dx + 23, pos.dy - 18, pos.dx, pos.dy + 17);
      canvas.drawPath(path, Paint()..color = const Color(0xFF51C7B5));
      canvas.drawCircle(
        pos.translate(0, -5),
        4,
        Paint()..color = const Color(0xFFE8ECE9),
      );
    }
  }

  @override
  bool shouldRepaint(_MapFixture old) => false;
}
