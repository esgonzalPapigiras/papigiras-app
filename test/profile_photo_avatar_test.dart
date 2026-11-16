import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';

class PhotoProvider extends CoordinatorProviders {
  Uint8List? photo;
  bool failUpload = false;
  int uploads = 0;
  String? passengerId;
  String? tourId;
  Completer<void>? pending;

  @override
  Future<Uint8List?> getCoordinatorPicture() async => photo;

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String passenger,
    String tour,
  ) async =>
      Responseimagepassenger(image: photo == null ? '' : base64Encode(photo!));

  Future<void> save(XFile image) async {
    uploads++;
    if (failUpload) throw Exception('Fallo de prueba');
    await pending?.future;
    photo = await image.readAsBytes();
  }

  @override
  Future<void> updateCoordinatorPicture(XFile image) => save(image);

  @override
  Future<void> addHitoFotoPassenger(
    String passenger,
    String tour,
    XFile image,
  ) {
    passengerId = passenger;
    tourId = tour;
    return save(image);
  }
}

void main() {
  late PhotoProvider provider;
  late XFile selected;
  late int pickerCalls;
  setUp(() async {
    provider = PhotoProvider();
    pickerCalls = 0;
    final image = await rootBundle.load('assets/profile.jpg');
    selected = XFile.fromData(
      image.buffer.asUint8List(),
      name: 'perfil-ficticio.jpg',
    );
  });
  tearDown(() => provider.dispose());

  Future<void> show(
    WidgetTester tester, {
    bool passenger = false,
    bool cancel = false,
    double radius = 50,
    VoidCallback? onOpenProfile,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProfilePhotoAvatar(
              radius: radius,
              passenger: passenger ? LabFixtures.passenger : null,
              provider: provider,
              onOpenProfile: onOpenProfile,
              pickImage: () async {
                pickerCalls++;
                return cancel ? null : selected;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cancelar la galería conserva la foto y no envía archivos', (
    tester,
  ) async {
    await show(tester, cancel: true);
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pumpAndSettle();
    expect(provider.uploads, 0);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isA<AssetImage>(),
    );
    expect(find.text('Foto de perfil actualizada'), findsNothing);
  });

  testWidgets('un fallo de guardado conserva la foto y permite reintentar', (
    tester,
  ) async {
    provider.failUpload = true;
    await show(tester);
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isA<AssetImage>(),
    );
    expect(
      find.text('No se pudo guardar la foto. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.text('Foto de perfil actualizada'), findsNothing);
  });

  for (final passenger in [false, true]) {
    testWidgets(
      '${passenger ? 'alumno/apoderado' : 'coordinador'} guarda una sola vez y vuelve a cargar la foto',
      (tester) async {
        provider.pending = Completer<void>();
        await show(tester, passenger: passenger);
        await tester.tap(find.byIcon(Icons.camera_alt_rounded));
        await tester.pump();
        await tester.tap(find.byType(InkWell));
        await tester.pump();
        expect(provider.uploads, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        provider.pending!.complete();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CircleAvatar>(find.byType(CircleAvatar))
              .backgroundImage,
          isA<MemoryImage>(),
        );
        expect(find.text('Foto de perfil actualizada'), findsOneWidget);
        if (passenger) {
          expect(
            provider.passengerId,
            LabFixtures.passenger.passengerId.toString(),
          );
          expect(provider.tourId, LabFixtures.passenger.tourId.toString());
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await show(tester, passenger: passenger);
        expect(
          tester
              .widget<CircleAvatar>(find.byType(CircleAvatar))
              .backgroundImage,
          isA<MemoryImage>(),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'la foto guardada se sincroniza con otra vista del mismo perfil',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ProfilePhotoAvatar(
                  radius: 50,
                  provider: provider,
                  pickImage: () async => selected,
                ),
                ProfilePhotoAvatar(radius: 35, provider: provider),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.camera_alt_rounded).first);
      await tester.pumpAndSettle();
      final avatars = tester.widgetList<CircleAvatar>(
        find.byType(CircleAvatar),
      );
      expect(avatars, hasLength(2));
      for (final avatar in avatars) {
        expect(avatar.backgroundImage, isA<MemoryImage>());
      }
      expect(provider.uploads, 1);
    },
  );

  for (final radius in [35.0, 50.0]) {
    testWidgets(
      'coordinator avatar center at radius $radius opens only the profile',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var profileOpens = 0;
          await show(
            tester,
            radius: radius,
            onOpenProfile: () => profileOpens++,
          );
          expect(find.bySemanticsLabel('Abrir mi perfil'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Cambiar foto de perfil'),
            findsOneWidget,
          );
          await tester.tapAt(tester.getCenter(find.byType(CircleAvatar)));
          await tester.pumpAndSettle();
          expect(profileOpens, 1);
          expect(pickerCalls, 0);
          expect(provider.uploads, 0);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('coordinator camera changes photo without opening profile', (
    tester,
  ) async {
    var profileOpens = 0;
    await show(tester, onOpenProfile: () => profileOpens++);
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pumpAndSettle();
    expect(profileOpens, 0);
    expect(pickerCalls, 1);
    expect(provider.uploads, 1);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isA<MemoryImage>(),
    );
    expect(find.text('Foto de perfil actualizada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final passenger in [false, true]) {
    testWidgets(
      '${passenger ? 'family/student' : 'coordinator'} default body still edits the photo',
      (tester) async {
        await show(tester, passenger: passenger);
        await tester.tapAt(tester.getCenter(find.byType(CircleAvatar)));
        await tester.pumpAndSettle();
        expect(pickerCalls, 1);
        expect(provider.uploads, 1);
        if (passenger) {
          expect(
            provider.passengerId,
            LabFixtures.passenger.passengerId.toString(),
          );
          expect(provider.tourId, LabFixtures.passenger.tourId.toString());
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'profile navigation opt-in does not replace family/student photo editing',
    (tester) async {
      var profileOpens = 0;
      await show(tester, passenger: true, onOpenProfile: () => profileOpens++);
      await tester.tapAt(tester.getCenter(find.byType(CircleAvatar)));
      await tester.pumpAndSettle();
      expect(profileOpens, 0);
      expect(pickerCalls, 1);
      expect(provider.uploads, 1);
      expect(
        provider.passengerId,
        LabFixtures.passenger.passengerId.toString(),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
