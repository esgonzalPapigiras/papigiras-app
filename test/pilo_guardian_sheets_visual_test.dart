import 'support/visual_capture.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:papigiras_app/design/family_home.dart';
import 'package:papigiras_app/design/pilo_family_medical_preview.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';
import 'support/ux_demo_images.dart' show uxLagoonPhoto;

final _login = ResponseAttorney(
  passengerId: 910011,
  tourId: 910001,
  passengerName: 'SOFÍA ISABEL',
  passengerApellidos: 'TORRES EJEMPLO',
  passengerIdentificacion: 'LAB-910011',
);

class _FixtureProvider extends CoordinatorProviders {
  @override
  Future<PassengersMedicalRecordDTO> getMedicalRecord(
    String tour,
    String passenger,
  ) async {
    expect([tour, passenger], ['910001', '910011']);
    return PassengersMedicalRecordDTO.fromJson({
      'idPassengersMedicalRecord': 910011,
      'passengerId': 910011,
      'tourSalesId': 910001,
      'fechaAutorizacion': '2026-11-12T12:30:00Z',
    });
  }

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async {
    expect([rut, tour], ['LAB-910011', '910001']);
    return Responseimagepassenger(image: uxLagoonPhoto);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  captureTest('Option A medical, menu and profile sheets visual fixture', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _FixtureProvider();
    addTearDown(provider.dispose);
    final boundary = GlobalKey();
    late BuildContext origin;
    void openMenu() {
      AppDrawerFather.showPiloSheet(
        origin,
        login: _login,
        photoProvider: provider,
        passwordProvider: provider,
        pickImage: () async => null,
        onTripDetails: () {},
        onMedical: () {},
        onDocuments: () {},
        onCrew: () {},
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: PiloFamilyTheme.theme(ThemeData()),
        builder: (context, child) => RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 48, bottom: 24)),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) {
            origin = context;
            return Scaffold(
              body: SafeArea(
                bottom: false,
                child: FamilyHome(
                  showNavigation: false,
                  givenNames: 'SOFÍA ISABEL',
                  surnames: 'TORRES EJEMPLO',
                  rut: 'LAB-910011',
                  school: 'COLEGIO HORIZONTE LAB',
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
                        color: PiloFamilyTheme.accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  map: const ColoredBox(
                    color: Color(0xFFE9EEEC),
                    child: Center(
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 36,
                        color: PiloFamilyTheme.mint,
                      ),
                    ),
                  ),
                  onMedical: () {},
                  onDiary: () {},
                  onCrew: () {},
                  onDocuments: () {},
                  onMap: () {},
                  onGallery: () {},
                  onMenu: openMenu,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      if (Platform.environment['PILO_SHEETS_CAPTURE'] != '1') return;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = visualCaptureFile(
          'registro-local/PILO-APODERADO-INICIO-A/evidencia/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    showPiloFamilyMedicalPreview(origin, login: _login, provider: provider);
    await tester.pumpAndSettle();
    expect(find.text('Ficha guardada'), findsOneWidget);
    expect(find.text('Autorizada el 12 de noviembre de 2026'), findsOneWidget);
    expect(find.text('Ver y editar ficha'), findsOneWidget);
    final medicalButton = tester.getRect(
      find.byKey(const ValueKey('family-medical-preview-open')),
    );
    expect(medicalButton.bottom, lessThan(850));
    await capture('ficha-medica-a-fixture');
    await tester.tap(find.byTooltip('Cerrar vista previa de ficha médica'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('family-home-menu')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pilo-family-menu-sheet')),
      findsOneWidget,
    );
    final profile = find.byKey(const ValueKey('pilo-family-menu-profile'));
    expect(tester.getRect(profile).bottom, lessThan(850));
    await capture('menu-a-fixture');

    await tester.tap(profile);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, boundary.currentContext!);
      }
      for (final avatar in tester.widgetList<CircleAvatar>(
        find.byType(CircleAvatar),
      )) {
        if (avatar.backgroundImage != null) {
          await precacheImage(
            avatar.backgroundImage!,
            boundary.currentContext!,
          );
        }
      }
    });
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pilo-family-profile-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('family-menu-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('family-menu-logout')), findsOneWidget);
    await capture('perfil-estudiante-a-fixture');
  });
}
