import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/documents/documents_ui.dart';
import 'package:papigiras_app/documents/internal_documents_repository.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

Document fixture(
  String title, {
  bool visible = true,
  String? name = 'archivo.pdf',
}) => Document(
  documentName: name,
  documentType: title,
  tourSalesUuid: 'gira-fixture',
  visibleToAll: visible,
);

class _Provider extends CoordinatorProviders {
  List<Document> documents = [fixture('Programa de la gira')];
  bool fail = false, failAction = false;
  int internalReads = 0, lists = 0;
  Completer<void>? action;
  Completer<List<Document>>? pending;
  final actions = <List<String>>[];
  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async => Responseimagepassenger(image: '');
  @override
  Future<List<Document>> getDocument(String tour) async {
    lists++;
    if (fail) throw StateError('secret technical payload');
    return pending == null ? List.of(documents) : pending!.future;
  }

  @override
  Future<List<InternalTourDocument>> listInternalDocuments(int tourId) async {
    internalReads++;
    throw StateError('Family must never request internal files');
  }

  @override
  Future<void> viewDocument(
    String folder,
    String name,
    String tour,
    BuildContext context,
    String type,
  ) async {
    actions.add(['view', folder, name, tour, type]);
    if (failAction) throw StateError('secret technical payload');
    await action?.future;
  }

  @override
  Future<void> downloadDocument(
    String folder,
    String name,
    String tour,
    String type,
  ) async {
    actions.add(['save', folder, name, tour, type]);
    if (failAction) throw StateError('secret technical payload');
    await action?.future;
  }
}

void main() {
  late _Provider provider;
  setUp(() => provider = _Provider());
  tearDown(() => provider.dispose());
  Future<void> show(
    WidgetTester tester, {
    double scale = 1,
    double width = 393,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: DocumentFatherScreen(
          login: LabFixtures.passenger,
          provider: provider,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('family preserves visibility and never loads private documents', (
    tester,
  ) async {
    provider.documents = [
      fixture('extra', name: 'Autorización de viaje.pdf'),
      fixture('extra', name: 'Equipaje y recomendaciones.docx'),
      fixture('Privado', visible: false, name: 'Privado.pdf'),
      fixture('Nomina alumnos', name: 'Nómina de prueba.pdf'),
    ];
    await show(tester);
    expect(find.text('Autorización de viaje.pdf'), findsOneWidget);
    expect(find.text('Equipaje y recomendaciones.docx'), findsOneWidget);
    expect(find.text('Más archivos'), findsNothing);
    expect(find.text('Documento adicional'), findsNothing);
    expect(find.text('Privado.pdf'), findsNothing);
    expect(find.text('Nómina de prueba.pdf'), findsNothing);
    expect(find.byKey(const ValueKey('documents-add')), findsNothing);
    expect(provider.internalReads, 0);
  });

  testWidgets(
    'load failure is not an empty list; retry recovers without raw payload',
    (tester) async {
      provider.fail = true;
      await show(tester);
      expect(find.text('No pudimos cargar los documentos.'), findsOneWidget);
      expect(find.text('Aún no hay documentos'), findsNothing);
      expect(find.textContaining('technical payload'), findsNothing);
      provider.fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('archivo.pdf'), findsOneWidget);
    },
  );

  testWidgets('empty state only after response and refresh is available', (
    tester,
  ) async {
    provider.pending = Completer<List<Document>>();
    await show(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Aún no hay documentos'), findsNothing);
    provider.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay documentos'), findsOneWidget);
    provider.pending = null;
    await tester.tap(find.byTooltip('Actualizar documentos'));
    await tester.pumpAndSettle();
    expect(find.text('archivo.pdf'), findsOneWidget);
  });

  testWidgets(
    'long family filename has room and open and save use the full name',
    (tester) async {
      const name =
          'PROGRAMA DE LA GIRA Y RECOMENDACIONES PARA FAMILIAS - COPIA DE PRUEBA.pdf';
      provider.documents = [fixture('extra', name: name)];
      await show(tester);

      final title = find.text(name);
      expect(title, findsOneWidget);
      final titleBounds = tester.getRect(title);
      final openBounds = tester.getRect(find.byTooltip('Ver documento'));
      expect(titleBounds.width, greaterThan(280));
      expect(titleBounds.bottom, lessThan(openBounds.top));

      await tester.tap(find.byTooltip('Ver documento'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Guardar documento'));
      await tester.pumpAndSettle();
      expect(provider.actions, [
        [
          'view',
          'gira-fixture',
          name,
          '${LabFixtures.passenger.tourId}',
          'documentosextras',
        ],
        [
          'save',
          'gira-fixture',
          name,
          '${LabFixtures.passenger.tourId}',
          'documentosextras',
        ],
      ]);
      expect(find.textContaining('simulada'), findsNothing);
      expect(find.textContaining('Éxito'), findsNothing);
    },
  );

  testWidgets('file action is single flight and failure can be retried', (
    tester,
  ) async {
    provider.action = Completer<void>();
    await show(tester);
    await tester.tap(find.byTooltip('Guardar documento'));
    await tester.pump();
    expect(find.byTooltip('Guardar documento'), findsNothing);
    expect(provider.actions.length, 1);
    provider.action!.completeError(StateError('secret technical payload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Inténtalo nuevamente'), findsOneWidget);
    expect(find.textContaining('technical payload'), findsNothing);
    provider.action = null;
    await tester.tap(find.byTooltip('Guardar documento'));
    await tester.pumpAndSettle();
    expect(provider.actions.length, 2);
  });

  testWidgets('missing file cannot be opened or saved', (tester) async {
    provider.documents = [fixture('Archivo pendiente', name: null)];
    await show(tester);
    expect(find.text('Archivo no disponible'), findsOneWidget);
    expect(find.byTooltip('Ver documento'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('Guardar documento'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
    expect(provider.actions, isEmpty);
  });

  testWidgets(
    '320 width and 200 percent text keep titles and actions reachable',
    (tester) async {
      provider.documents = [
        fixture(
          'gira',
          name:
              'Programa de actividades y recomendaciones para todo el viaje.pdf',
        ),
        fixture('Póliza', name: 'Póliza.pdf'),
      ];
      await show(tester, scale: 2, width: 320);
      expect(find.text('Más archivos'), findsNothing);
      final save = find.byTooltip('Guardar documento').first;
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(provider.actions.single.first, 'save');
      expect(tester.getSize(save).width, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving during pending read does not update disposed screen', (
    tester,
  ) async {
    provider.pending = Completer<List<Document>>();
    await show(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    provider.pending!.complete([fixture('Programa')]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh clears removed file and back preserves prior route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DocumentFatherScreen(
                    login: LabFixtures.passenger,
                    provider: provider,
                  ),
                ),
              ),
              child: const Text('Inicio de prueba'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Inicio de prueba'));
    await tester.pumpAndSettle();
    provider.documents = [];
    await tester.tap(find.byTooltip('Actualizar documentos'));
    await tester.pumpAndSettle();
    expect(find.text('archivo.pdf'), findsNothing);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Inicio de prueba'), findsOneWidget);
    expect(find.byType(DocumentFatherScreen), findsNothing);
  });

  testWidgets('shared tile supports long internal metadata at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppleDesignTrialScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                children: [
                  PapiDocumentTile(
                    title: 'Voucher de actividad con nombre extenso',
                    subtitle: 'Actividad histórica · 13/11/2026 · 9.9 MB',
                    onSave: () => saved = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byTooltip('Guardar documento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Guardar documento'));
    expect(saved, isTrue);
    expect(tester.takeException(), isNull);
  });
}
