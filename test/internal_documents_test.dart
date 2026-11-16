import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/documents/internal_document_media.dart';
import 'package:papigiras_app/documents/internal_document_upload.dart';
import 'package:papigiras_app/documents/internal_documents_repository.dart';
import 'package:papigiras_app/dto/Itinerary.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

InternalTourDocument doc(
  String id, {
  InternalDocumentCategory category = InternalDocumentCategory.general,
  String mime = 'application/pdf',
}) => InternalTourDocument(
  id: id,
  tourId: 910001,
  category: category,
  name: 'Documento ficticio $id',
  originalName: 'seleccion.pdf',
  storedName: 'documento_20261105_giraLAB_$id.pdf',
  contentType: mime,
  sizeBytes: 10,
  createdAt: DateTime.utc(2026, 11, 5),
  activityId: category == InternalDocumentCategory.voucher ? 910050 : null,
  activityName: category == InternalDocumentCategory.voucher
      ? 'Museo de prueba'
      : null,
);

class _DocumentsProvider extends CoordinatorProviders {
  final documents = <InternalTourDocument>[
    doc('general'),
    doc('voucher', category: InternalDocumentCategory.voucher),
    doc('word', mime: 'application/msword'),
  ];
  bool failInternal = false, failUpload = false, failActivities = false;
  int lists = 0, uploads = 0, activityRequests = 0;
  final downloads = <(int, String)>[];
  final publicActions = <String>[];
  List<Itinerary> activities = [
    Itinerary(itinerary: 'Museo de prueba', itineraryId: 910050),
  ];
  Completer<InternalTourDocument>? pendingUpload;
  void Function(double)? progress;
  InternalDocumentFile? uploadedFile;
  String? uploadedName;
  InternalDocumentCategory? uploadedCategory;
  int? uploadedActivity;
  @override
  Future<List<Document>> getDocument(String tour) async => [
    Document(
      documentName: 'programa-publico.pdf',
      documentType: 'Programa de la gira',
      tourSalesUuid: 'gira-ficticia',
      visibleToAll: true,
    ),
  ];
  @override
  Future<List<InternalTourDocument>> listInternalDocuments(int tourId) async {
    lists++;
    if (failInternal) throw StateError('Payload técnico');
    return List.of(documents);
  }

  @override
  Future<List<Itinerary>> getInternalDocumentActivities(int tourId) async {
    activityRequests++;
    if (failActivities) throw StateError('Payload técnico');
    return activities;
  }

  @override
  Future<InternalTourDocument> uploadInternalDocument({
    required int tourId,
    required String name,
    required InternalDocumentCategory category,
    int? activityId,
    required InternalDocumentFile file,
    void Function(double)? onProgress,
  }) async {
    uploads++;
    uploadedName = name;
    uploadedCategory = category;
    uploadedActivity = activityId;
    uploadedFile = file;
    progress = onProgress;
    if (failUpload) throw StateError('Payload técnico');
    final result = pendingUpload == null
        ? doc('nuevo', category: category)
        : await pendingUpload!.future;
    documents.add(result);
    return result;
  }

  @override
  Future<InternalDocumentDownload> downloadInternalDocument({
    required int tourId,
    required String documentId,
  }) async {
    downloads.add((tourId, documentId));
    return InternalDocumentDownload(
      fileName: 'guardado.pdf',
      contentType: 'application/pdf',
      bytes: Uint8List.fromList([37, 80, 68, 70, 45]),
    );
  }

  @override
  Future<void> viewDocument(
    String folder,
    String name,
    String tour,
    BuildContext context,
    String type,
  ) async {
    publicActions.add('view:$type');
  }

  @override
  Future<void> downloadDocument(
    String folder,
    String name,
    String tour,
    String type,
  ) async {
    publicActions.add('save:$type');
  }
}

class _Media implements InternalDocumentMedia {
  InternalDocumentFile? selected = InternalDocumentFile(
    fileName: 'prueba.pdf',
    contentType: 'application/pdf',
    bytes: Uint8List.fromList([37, 80, 68, 70, 45]),
  );
  Completer<InternalDocumentFile?>? pending;
  final picked = <InternalDocumentSource>[];
  int previews = 0, saves = 0;
  @override
  Future<InternalDocumentFile?> pick(InternalDocumentSource source) async {
    picked.add(source);
    return pending == null ? selected : await pending!.future;
  }

  @override
  Future<void> preview(
    BuildContext context,
    InternalDocumentDownload file,
  ) async {
    previews++;
  }

  @override
  Future<bool> save(InternalDocumentDownload file) async {
    saves++;
    return false;
  }
}

void main() {
  late _DocumentsProvider provider;
  late _Media media;
  late LocationService location;
  late TourSales login;
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    SharedPreferences.setMockInitialValues({});
    LabFixtures.reset();
    provider = _DocumentsProvider();
    media = _Media();
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
  Future<void> show(
    WidgetTester tester, {
    double width = 393,
    double height = 852,
    double scale = 1,
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
          home: DocumentCoordScreen(
            login: login,
            provider: provider,
            media: media,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));
  Future<void> tap(WidgetTester tester, String value) async {
    await tester.ensureVisible(key(value));
    await tester.tap(key(value));
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester) async {
    await tap(tester, 'documents-add');
  }

  Future<void> name(WidgetTester tester, String value) async {
    await tester.enterText(key('internal-upload-name'), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  test(
    'archivo admite límite exacto10MiB y rechaza vacío/exceso/tipo ajeno',
    () {
      expect(
        () => validateInternalDocumentFile(
          InternalDocumentFile(
            fileName: 'prueba.xlsx',
            contentType: internalDocumentMime('xlsx'),
            bytes: Uint8List(internalDocumentMaxBytes),
          ),
        ),
        returnsNormally,
      );
      for (final file in [
        InternalDocumentFile(
          fileName: 'vacío.pdf',
          contentType: 'application/pdf',
          bytes: Uint8List(0),
        ),
        InternalDocumentFile(
          fileName: 'grande.pdf',
          contentType: 'application/pdf',
          bytes: Uint8List(internalDocumentMaxBytes + 1),
        ),
        InternalDocumentFile(
          fileName: 'pagina.html',
          contentType: 'text/html',
          bytes: Uint8List(4),
        ),
      ]) {
        expect(
          () => validateInternalDocumentFile(file),
          throwsA(isA<InternalDocumentValidationException>()),
        );
      }
    },
  );
  testWidgets(
    'secciones separan documentos anteriores de internos y vouchers',
    (tester) async {
      await show(tester);
      expect(find.text('programa-publico.pdf'), findsOneWidget);
      expect(find.text('Documento ficticio general'), findsOneWidget);
      expect(find.text('Documento ficticio voucher'), findsNothing);
      expect(find.text('Solo coordinación y administración'), findsOneWidget);
      await tap(tester, 'documents-section-VOUCHER');
      expect(find.text('programa-publico.pdf'), findsNothing);
      expect(find.text('Documento ficticio voucher'), findsOneWidget);
      expect(find.textContaining('Museo de prueba'), findsOneWidget);
      expect(provider.uploads, 0);
      expect(media.picked, isEmpty);
    },
  );
  testWidgets(
    'nombre y archivo son obligatorios; cancelar selector no sube nada',
    (tester) async {
      await show(tester);
      await add(tester);
      await tap(tester, 'internal-upload-submit');
      expect(find.text('Escribe un nombre para el documento.'), findsOneWidget);
      expect(find.text('Elige una foto o un archivo.'), findsOneWidget);
      expect(provider.uploads, 0);
      await name(tester, '  Documento con nombre  ');
      media.selected = null;
      await tap(tester, 'internal-upload-file');
      await tap(tester, 'internal-upload-submit');
      expect(provider.uploads, 0);
      expect(media.picked, [InternalDocumentSource.file]);
    },
  );
  testWidgets(
    'voucher usa sólo nombre escrito; progreso100 no significa éxito',
    (tester) async {
      provider.pendingUpload = Completer<InternalTourDocument>();
      await show(tester);
      await tap(tester, 'documents-section-VOUCHER');
      await add(tester);
      await name(tester, '  Entrada museo  ');
      await tap(tester, 'internal-upload-gallery');
      expect(
        find.byKey(const ValueKey('internal-upload-activity')),
        findsNothing,
      );
      expect(provider.activityRequests, 0);
      await tester.ensureVisible(key('internal-upload-submit'));
      await tester.tap(key('internal-upload-submit'));
      await tester.pump();
      expect(provider.uploads, 1);
      expect(provider.uploadedActivity, isNull);
      expect(provider.uploadedCategory, InternalDocumentCategory.voucher);
      expect(provider.uploadedName, 'Entrada museo');
      expect(media.picked, [InternalDocumentSource.gallery]);
      provider.progress!(.5);
      await tester.pump();
      expect(find.text('50 % enviado'), findsOneWidget);
      provider.progress!(1);
      await tester.pump();
      expect(find.text('Confirmando archivo…'), findsOneWidget);
      expect(find.byType(InternalDocumentUploadScreen), findsOneWidget);
      expect(find.text('Documento agregado.'), findsNothing);
      provider.pendingUpload!.complete(
        doc('nuevo', category: InternalDocumentCategory.voucher),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InternalDocumentUploadScreen), findsNothing);
      expect(find.text('Documento ficticio nuevo'), findsOneWidget);
      expect(find.text('Documento agregado.'), findsOneWidget);
    },
  );
  testWidgets(
    'error de subida conserva nombre/archivo para reintento sin datos técnicos',
    (tester) async {
      provider.failUpload = true;
      await show(tester);
      await add(tester);
      await name(tester, 'Comprobante de prueba');
      await tap(tester, 'internal-upload-camera');
      await tap(tester, 'internal-upload-submit');
      expect(provider.uploads, 1);
      expect(find.textContaining('Tus datos siguen aquí'), findsOneWidget);
      expect(find.textContaining('Payload técnico'), findsNothing);
      expect(find.text('Comprobante de prueba'), findsOneWidget);
      expect(find.text('prueba.pdf'), findsOneWidget);
      provider.failUpload = false;
      await tap(tester, 'internal-upload-submit');
      expect(provider.uploads, 2);
      expect(provider.uploadedActivity, isNull);
      expect(find.byType(InternalDocumentUploadScreen), findsNothing);
    },
  );
  testWidgets('tipo no permitido y archivo superior10MB bloquean subida', (
    tester,
  ) async {
    await show(tester);
    await add(tester);
    await name(tester, 'Archivo prueba');
    media.selected = InternalDocumentFile(
      fileName: 'página.svg',
      contentType: 'image/svg+xml',
      bytes: Uint8List(10),
    );
    await tap(tester, 'internal-upload-file');
    expect(find.textContaining('Elige un PDF'), findsOneWidget);
    media.selected = InternalDocumentFile(
      fileName: 'largo.pdf',
      contentType: 'application/pdf',
      bytes: Uint8List(internalDocumentMaxBytes + 1),
    );
    await tap(tester, 'internal-upload-file');
    expect(find.textContaining('supera los 10 MB'), findsOneWidget);
    expect(provider.uploads, 0);
  });
  testWidgets(
    'PDF tiene vista previa y Office sólo guardar; no comparte automáticamente',
    (tester) async {
      await show(tester);
      final general = key('internal-document-general');
      final word = key('internal-document-word');
      final view = find.descendant(
        of: general,
        matching: find.byTooltip('Ver documento'),
      );
      await tester.ensureVisible(view);
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(media.previews, 1);
      expect(provider.downloads.last, (login.tourSalesId, 'general'));
      expect(
        find.descendant(of: word, matching: find.byTooltip('Ver documento')),
        findsNothing,
      );
      final save = find.descendant(
        of: word,
        matching: find.byTooltip('Guardar documento'),
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(media.saves, 1);
      expect(provider.downloads.last, (login.tourSalesId, 'word'));
      expect(find.text('Documento guardado.'), findsNothing);
    },
  );
  testWidgets(
    'error internos no oculta documentos anteriores y permite reintentar',
    (tester) async {
      provider.failInternal = true;
      await show(tester);
      expect(find.text('programa-publico.pdf'), findsOneWidget);
      expect(
        find.text('No pudimos cargar los documentos internos.'),
        findsOneWidget,
      );
      provider.failInternal = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Documento ficticio general'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'voucher se guarda aunque no haya programa ni servicio de actividades',
    (tester) async {
      provider.failActivities = true;
      provider.activities = [];
      await show(tester);
      await tap(tester, 'documents-section-VOUCHER');
      await add(tester);
      expect(
        find.byKey(const ValueKey('internal-upload-activity')),
        findsNothing,
      );
      await name(tester, 'Voucher sin actividad');
      await tap(tester, 'internal-upload-file');
      await tap(tester, 'internal-upload-submit');
      expect(provider.uploads, 1);
      expect(provider.uploadedName, 'Voucher sin actividad');
      expect(provider.uploadedActivity, isNull);
      expect(provider.activityRequests, 0);
    },
  );
  testWidgets(
    'volver mientras selector espera no dispara subida ni setState tras dispose',
    (tester) async {
      media.pending = Completer<InternalDocumentFile?>();
      await show(tester);
      await add(tester);
      await tester.tap(key('internal-upload-camera'));
      await tester.pump();
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      media.pending!.complete(media.selected);
      await tester.pumpAndSettle();
      expect(provider.uploads, 0);
      expect(find.byType(DocumentCoordScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '320px texto1,6 mantiene formulario, errores y acciones sin overflow',
    (tester) async {
      await show(tester, width: 320, height: 740, scale: 1.6);
      await add(tester);
      await name(tester, List.filled(8, 'Nombre largo').join(' '));
      final formScroll = find
          .descendant(
            of: find.byType(InternalDocumentUploadScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        key('internal-upload-file'),
        160,
        scrollable: formScroll,
      );
      await tester.ensureVisible(key('internal-upload-file'));
      await tester.pumpAndSettle();
      await tester.tap(key('internal-upload-file'));
      await tester.pumpAndSettle();
      expect(media.picked, [InternalDocumentSource.file]);
      await tester.scrollUntilVisible(
        key('internal-upload-submit'),
        160,
        scrollable: formScroll,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(key('internal-upload-submit')).height,
        greaterThanOrEqualTo(44),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
