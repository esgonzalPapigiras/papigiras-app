import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/ranking/coordinator_ranking_repository.dart';
import 'package:papigiras_app/ranking/coordinator_ranking_screen.dart';

const _rule = CoordinatorRankingRule(
  version: '1',
  hitoPoints: 10,
  photoPoints: 1,
  likePoints: 2,
);
const _names = [
  ('VALENTINA ANDREA', 'CRUZ SOTO'),
  ('MATEO JOSÉ', 'RÍOS PÉREZ'),
  ('ANTONIA PAZ', 'VERA DÍAZ'),
  ('TOMÁS SEBASTIÁN', 'SILVA REYES'),
  ('ISIDORA BELÉN', 'LAGOS MORA'),
  ('BENJAMÍN ANDRÉS', 'ROJAS LARA'),
  ('EMILIA JOSEFA', 'TORRES RUIZ'),
  ('VICENTE ALONSO', 'DÍAZ LEÓN'),
  ('SOFÍA ANTONIA', 'MUÑOZ VEGA'),
  ('MARTÍN IGNACIO', 'PÉREZ OYARZÚN'),
  ('JOAQUÍN', 'SOTO'),
];
CoordinatorRankingEntry entry(int rank, {bool picture = false}) {
  final pair = _names[(rank - 1) % _names.length];
  return CoordinatorRankingEntry(
    rank: rank,
    coordinatorId: 910000 + rank,
    firstName: pair.$1,
    lastName: pair.$2,
    photoAvailable: picture,
    bestTourId: 910001 + rank,
    hitoCount: 25 - rank,
    photoCount: 80 - rank * 3,
    likeCount: 100 - rank * 5,
    score: (25 - rank) * 10 + 80 - rank * 3 + (100 - rank * 5) * 2,
  );
}

CoordinatorRankingPage page({
  int season = 2025,
  List<CoordinatorRankingEntry>? entries,
  CoordinatorRankingEntry? mine,
  bool empty = false,
  int offset = 0,
  int limit = 50,
  bool more = false,
  int total = 11,
  int unattributed = 0,
}) => CoordinatorRankingPage(
  season: season,
  availableSeasons: const [2024, 2025, 2026],
  generatedAt: DateTime.utc(2026, 11, 15),
  rule: _rule,
  totalParticipants: empty ? 0 : total,
  currentCoordinatorId: 910006,
  myEntry: empty ? null : mine ?? entry(6),
  entries: empty
      ? []
      : entries ?? List.generate(11, (index) => entry(index + 1)),
  limit: limit,
  offset: offset,
  hasMore: more,
  unattributedHitoCount: unattributed,
);

class _Repository implements CoordinatorRankingRepository {
  final calls = <({int season, int limit, int offset})>[];
  final photoCalls = <({int season, int id})>[];
  Future<CoordinatorRankingPage> Function(int season, int offset)? read;
  Future<Uint8List?> Function(int id)? photo;
  @override
  Future<CoordinatorRankingPage> load({
    required int season,
    int limit = 50,
    int offset = 0,
  }) {
    calls.add((season: season, limit: limit, offset: offset));
    return read?.call(season, offset) ?? Future.value(page(season: season));
  }

  @override
  Future<Uint8List?> loadPicture({
    required int season,
    required int coordinatorId,
    bool refresh = false,
  }) {
    photoCalls.add((season: season, id: coordinatorId));
    return photo?.call(coordinatorId) ?? Future.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capture = Platform.environment['PILO_RANKING_CAPTURE'] == '1';
  setUpAll(() async {
    if (!capture) return;
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  final boundary = GlobalKey();
  Future<void> show(
    WidgetTester tester,
    _Repository repository, {
    double width = 402,
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: PiloFamilyTheme.theme(ThemeData(useMaterial3: true)),
        builder: (context, child) => RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
        home: CoordinatorRankingScreen(
          initialSeason: 2025,
          currentCoordinatorId: 910006,
          repository: repository,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    for (var index = 0; index < 20 && finder.evaluate().isEmpty; index++) {
      await tester.drag(
        find.byKey(const Key('ranking-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
    }
    if (finder.evaluate().isNotEmpty) await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    if (!capture) return;
    await tester.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final output = File(
      'registro-local/PILO-RANKING-COORDINADORES/evidencia/$name.png',
    );
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  testWidgets(
    'podium order, own position and metrics retain server values and title-case names',
    (tester) async {
      final repository = _Repository();
      await show(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text('Ranking'), findsOneWidget);
      expect(find.text('Valentina Cruz'), findsWidgets);
      expect(find.text('VALENTINA ANDREA'), findsNothing);
      expect(find.text('Tu puesto'), findsOneWidget);
      expect(find.text('#6'), findsOneWidget);
      final podium = find.byKey(const Key('ranking-podium'));
      final first = find.descendant(
        of: podium,
        matching: find.text('Valentina Cruz'),
      );
      final second = find.descendant(
        of: podium,
        matching: find.text('Mateo Ríos'),
      );
      final third = find.descendant(
        of: podium,
        matching: find.text('Antonia Vera'),
      );
      expect(tester.getCenter(second).dx, lessThan(tester.getCenter(first).dx));
      expect(tester.getCenter(first).dx, lessThan(tester.getCenter(third).dx));
      await scrollTo(tester, find.byKey(const Key('ranking-row-910006')));
      final row = find.byKey(const Key('ranking-row-910006'));
      expect(
        find.descendant(of: row, matching: find.text('19 hitos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('62 fotos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('70 likes')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('392')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Tú · Top 10')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('initial loading, error and retry remain actionable', (
    tester,
  ) async {
    final response = Completer<CoordinatorRankingPage>();
    final repository = _Repository()..read = (_, _) => response.future;
    await show(tester, repository);
    expect(find.text('Preparando la clasificación…'), findsOneWidget);
    response.completeError(StateError('synthetic unavailable'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-error')), findsOneWidget);
    repository.read = (season, _) async => page(season: season);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-podium')), findsOneWidget);
    expect(find.byKey(const Key('ranking-error')), findsNothing);
  });

  testWidgets(
    'empty season offers context without fabricated ranks or counts',
    (tester) async {
      final repository = _Repository()
        ..read = (season, _) async => page(season: season, empty: true);
      await show(tester, repository);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ranking-empty')), findsOneWidget);
      expect(find.byKey(const Key('ranking-my-empty')), findsOneWidget);
      expect(find.byKey(const Key('ranking-podium')), findsNothing);
      expect(find.text('#0'), findsNothing);
      expect(find.text('Tu próximo hito cuenta'), findsOneWidget);
    },
  );

  testWidgets(
    '403 explains coordinator sign-in without inventing permission or exposing rows',
    (tester) async {
      final repository = _Repository()
        ..read = (_, _) async => throw const LabApiException(403);
      await show(tester, repository);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Vuelve a iniciar sesión como coordinador para ver el ranking.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ranking-podium')), findsNothing);
    },
  );

  testWidgets(
    'unattributed historic activity displays a partial coverage notice',
    (tester) async {
      final repository = _Repository()
        ..read = (_, _) async => page(unattributed: 3);
      await show(tester, repository);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ranking-partial')), findsOneWidget);
      expect(
        find.textContaining(
          'Hay publicaciones antiguas sin autor registrado.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await snapshot(tester, 'ranking-parcial-fixture');
    },
  );

  testWidgets('season changes discard older response and scope photos', (
    tester,
  ) async {
    final old = Completer<CoordinatorRankingPage>();
    final fresh = Completer<CoordinatorRankingPage>();
    final repository = _Repository();
    repository.read = (season, _) => repository.calls.length == 1
        ? Future.value(page(entries: [entry(1, picture: true)]))
        : season == 2024
        ? old.future
        : fresh.future;
    await show(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-season')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporada 2024'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('ranking-season')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Previously known seasons remain available while a selection loads.
    expect(find.text('Temporada 2025'), findsOneWidget);
    await tester.tap(find.text('Temporada 2025'));
    await tester.pump(const Duration(milliseconds: 400));
    fresh.complete(page(entries: [entry(2, picture: true)]));
    await tester.pumpAndSettle();
    old.complete(page(season: 2024, entries: [entry(3)]));
    await tester.pumpAndSettle();
    expect(find.text('Mateo Ríos'), findsWidgets);
    expect(find.text('Antonia Vera'), findsNothing);
    expect(repository.calls.map((call) => call.season), [2025, 2024, 2025]);
  });

  testWidgets(
    'changed pagination offers a fresh load instead of repeating a stale cursor',
    (tester) async {
      final repository = _Repository();
      repository.read = (season, offset) async => offset == 0
          ? page(entries: [entry(1), entry(2), entry(3)], limit: 3, more: true)
          : page(entries: [entry(3), entry(4), entry(5)], offset: 3, limit: 3);
      await show(tester, repository);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('ranking-more')));
      await tester.tap(find.byKey(const Key('ranking-more')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('ranking-more')));
      expect(
        find.text(
          'El ranking cambió. Actualiza para ver las nuevas posiciones.',
        ),
        findsOneWidget,
      );
      expect(find.text('Actualizar'), findsOneWidget);
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      expect(repository.calls.map((call) => call.offset), [0, 3, 0]);
      expect(
        find.text(
          'El ranking cambió. Actualiza para ver las nuevas posiciones.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'network error on next page permits retry without losing existing entries',
    (tester) async {
      final repository = _Repository();
      repository.read = (season, offset) async {
        if (offset == 3) throw StateError('synthetic connection failure');
        return page(
          entries: [entry(1), entry(2), entry(3)],
          limit: 3,
          more: true,
        );
      };
      await show(tester, repository);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('ranking-more')));
      await tester.tap(find.byKey(const Key('ranking-more')));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar más coordinadores.'), findsOneWidget);
      repository.read = (season, offset) async =>
          page(entries: [entry(4), entry(5), entry(6)], limit: 3, offset: 3);
      await scrollTo(tester, find.byKey(const Key('ranking-more')));
      await tester.tap(find.byKey(const Key('ranking-more')));
      await tester.pumpAndSettle();
      expect(repository.calls.map((call) => call.offset), [0, 3, 3]);
      await scrollTo(tester, find.byKey(const Key('ranking-row-910006')));
      expect(find.byKey(const Key('ranking-row-910006')), findsOneWidget);
    },
  );

  testWidgets(
    'rules expose scoring, one best trip, tie order and a close control',
    (tester) async {
      await show(tester, _Repository());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ranking-rules')));
      await tester.pumpAndSettle();
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(
        find.text('Cuenta tu mejor gira de la temporada.'),
        findsOneWidget,
      );
      expect(find.textContaining('se comparte el puesto'), findsNothing);
      await snapshot(tester, 'ranking-reglas-fixture');
      await tester.tap(find.byKey(const Key('ranking-rules-close')));
      await tester.pumpAndSettle();
      expect(find.text('+10'), findsNothing);
    },
  );

  testWidgets(
    'pagination uses server cursor and retains own position outside first page',
    (tester) async {
      final repository = _Repository()
        ..read = (season, offset) async => offset == 0
            ? page(
                season: season,
                entries: [entry(1), entry(2), entry(3)],
                limit: 3,
                more: true,
              )
            : page(
                season: season,
                entries: [entry(4), entry(5), entry(6)],
                offset: 3,
                limit: 3,
              );
      await show(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text('#6'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('ranking-more')));
      await tester.tap(find.byKey(const Key('ranking-more')));
      await tester.pumpAndSettle();
      expect(repository.calls.last.offset, 3);
      await scrollTo(tester, find.byKey(const Key('ranking-row-910006')));
      expect(find.byKey(const Key('ranking-row-910006')), findsOneWidget);
    },
  );

  testWidgets('photo failure uses initials and never hides coordinator data', (
    tester,
  ) async {
    final repository = _Repository();
    repository.read = (season, _) async =>
        page(entries: [entry(1, picture: true)]);
    repository.photo = (_) =>
        Future.error(StateError('synthetic absent photo'));
    await show(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('VC'), findsWidgets);
    expect(find.text('Valentina Cruz'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sign-out clears visible data and rejects delayed ranking response',
    (tester) async {
      final delayed = Completer<CoordinatorRankingPage>();
      final repository = _Repository()..read = (_, _) => delayed.future;
      await show(tester, repository);
      await LabSession.clear(await SharedPreferences.getInstance());
      await tester.pump();
      delayed.complete(page());
      await tester.pumpAndSettle();
      expect(
        find.text('Tu sesión cambió. Vuelve a abrir el ranking.'),
        findsOneWidget,
      );
      expect(find.text('Valentina Cruz'), findsNothing);
      expect(find.byKey(const Key('ranking-podium')), findsNothing);
    },
  );

  testWidgets(
    '320 width and 200 percent text keep all data reachable with no overflow',
    (tester) async {
      await show(tester, _Repository(), width: 320, scale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await snapshot(tester, 'ranking-320-texto200-fixture');
      await scrollTo(tester, find.byKey(const Key('ranking-row-910011')));
      expect(find.byKey(const Key('ranking-row-910011')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fixture visual capture uses fictional names and local illustrated portraits',
    (tester) async {
      final portraits = <int, Uint8List?>{};
      await tester.runAsync(() async {
        for (var id = 910001; id <= 910011; id++) {
          portraits[id] = await _portrait(id);
        }
      });
      final repository = _Repository();
      repository.read = (season, _) async => page(
        entries: List.generate(11, (index) => entry(index + 1, picture: true)),
      );
      repository.photo = (id) async => portraits[id];
      await show(tester, repository);
      await tester.runAsync(() async {
        final context = tester.element(find.byType(CoordinatorRankingScreen));
        await Future.wait(
          portraits.values.map(
            (bytes) => precacheImage(MemoryImage(bytes!), context),
          ),
        );
      });
      await tester.pumpAndSettle();
      await snapshot(tester, 'ranking-inicio-fixture');
      await scrollTo(tester, find.byKey(const Key('ranking-row-910006')));
      await snapshot(tester, 'ranking-lista-fixture');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rules remain scrollable and dismissible with 200 percent text at 320 width',
    (tester) async {
      await show(tester, _Repository(), width: 320, scale: 2);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('ranking-rules')));
      await tester.tap(find.byKey(const Key('ranking-rules')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('ranking-rules-close')));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta tu mejor gira de la temporada.'), findsNothing);
    },
  );

  testWidgets(
    'podium adapts to one or two participants without invented prize winners',
    (tester) async {
      final repository = _Repository()
        ..read = (_, _) async =>
            page(entries: [entry(1), entry(2)], total: 2, mine: entry(2));
      await show(tester, repository);
      await tester.pumpAndSettle();
      final podium = find.byKey(const Key('ranking-podium'));
      expect(
        find.descendant(of: podium, matching: find.text('Valentina Cruz')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: podium, matching: find.text('Mateo Ríos')),
        findsOneWidget,
      );
      expect(find.text('Antonia Vera'), findsNothing);
      repository.read = (_, _) async =>
          page(entries: [entry(1)], total: 1, mine: entry(1));
      await tester.tap(find.byKey(const Key('ranking-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Mateo Ríos'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Synthetic avatar fixture; not a photograph of any real coordinator.
Future<Uint8List?> _portrait(int id) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();
  final color = [
    const Color(0xFFCFDDD4),
    const Color(0xFFE6D5C3),
    const Color(0xFFC6D5DF),
  ][id % 3];
  canvas.drawColor(color, BlendMode.src);
  paint.color = const Color(0xFF354F48);
  canvas.drawOval(const Rect.fromLTWH(20, 80, 88, 90), paint);
  paint.color = id.isEven ? const Color(0xFFC99774) : const Color(0xFFE4B28B);
  canvas.drawOval(const Rect.fromLTWH(39, 32, 50, 65), paint);
  paint.color = const Color(0xFF332C27);
  canvas.drawArc(const Rect.fromLTWH(34, 22, 62, 58), 3.14, 3.7, true, paint);
  canvas.drawCircle(const Offset(54, 61), 2.2, paint);
  canvas.drawCircle(const Offset(75, 61), 2.2, paint);
  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  canvas.drawArc(const Rect.fromLTWH(54, 68, 20, 13), .1, 2.8, false, paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(128, 128);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
