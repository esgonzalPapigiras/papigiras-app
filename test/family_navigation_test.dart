import 'package:papigiras_app/design/medical_form_components.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'medical_saved_form_test.dart' as medical;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';
import 'package:papigiras_app/utils/page_navigation.dart';

final events = <String>[];
final initialized = <FamilySection, int>{};
final disposed = <FamilySection>[];

class SectionFixture extends StatefulWidget {
  const SectionFixture(this.section, {super.key});
  final FamilySection section;
  @override
  State<SectionFixture> createState() => _SectionFixtureState();
}

class _SectionFixtureState extends State<SectionFixture> {
  final text = TextEditingController();
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    initialized.update(widget.section, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    disposed.add(widget.section);
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Section ${widget.section.name}'),
      leading: BackButton(
        onPressed: () => FamilyNavigationScope.maybeOf(context)!.back(),
      ),
    ),
    endDrawer: const Drawer(child: Text('fixture-drawer')),
    body: Column(
      children: [
        Text(
          TickerMode.of(context)
              ? 'active-${widget.section.name}'
              : 'paused-${widget.section.name}',
        ),
        TextField(
          key: ValueKey('draft-${widget.section.name}'),
          controller: text,
        ),
        Wrap(
          children: [
            TextButton(
              key: const ValueKey('detail'),
              onPressed: () => Navigator.of(context).push(
                buildPapiRoute(
                  Scaffold(
                    appBar: AppBar(title: const Text('Detail fixture')),
                    body: const Text('Detail content'),
                  ),
                ),
              ),
              child: const Text('Detail'),
            ),
            TextButton(
              key: const ValueKey('modal'),
              onPressed: () => showDialog<void>(
                context: context,
                useRootNavigator: false,
                builder: (dialogContext) => AlertDialog(
                  content: const Text('Confirmar fixture'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
              child: const Text('Modal'),
            ),
            TextButton(
              key: const ValueKey('pin'),
              onPressed: () =>
                  FamilyNavigationScope.maybeOf(context)!.openMap(910002),
              child: const Text('Pin'),
            ),
            TextButton(
              key: const ValueKey('logout'),
              onPressed: () => FamilyNavigationScope.maybeOf(context)!
                  .sessionNavigator
                  .pushAndRemoveUntil(
                    buildPapiRoute(const Scaffold(body: Text('Signed out'))),
                    (_) => false,
                  ),
              child: const Text('Logout'),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: 100,
            itemExtent: 48,
            itemBuilder: (_, i) => Text('Row $i'),
          ),
        ),
      ],
    ),
  );
}

Future<void> mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  events.clear();
  initialized.clear();
  disposed.clear();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        platform: platform,
        pageTransitionsTheme: papiPageTransitions,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(bottom: 24),
        ),
        child: child!,
      ),
      home: FamilyNavigation(
        onMapRequested: (id) => events.add('pin-$id'),
        builders: {
          for (final s in FamilySection.values) s: (_) => SectionFixture(s),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tab(WidgetTester tester, FamilySection s) async {
  await tester.tap(find.byKey(ValueKey('family-tab-${s.name}')));
  await tester.pumpAndSettle();
}

void expectBar(WidgetTester tester) {
  expect(find.byKey(const ValueKey('family-navigation-bar')), findsOneWidget);
  final xs = <double>[];
  for (final s in FamilySection.values.skip(1)) {
    final target = find.byKey(ValueKey('family-tab-${s.name}'));
    expect(target.hitTestable(), findsOneWidget);
    expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
    xs.add(tester.getCenter(target).dx);
  }
  expect(xs, orderedEquals([...xs]..sort()));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'Five destinations remain on every section and detail; lazy and no duplicate stacks',
    (t) async {
      await mount(t);
      expectBar(t);
      expect(initialized, {FamilySection.home: 1});
      for (final s in FamilySection.values.skip(1)) {
        await tab(t, s);
        expect(find.text('Section ${s.name}'), findsOneWidget);
        expectBar(t);
        await t.tap(find.byKey(const ValueKey('detail')));
        await t.pumpAndSettle();
        expectBar(t);
        expect(find.text('Detail content'), findsOneWidget);
        await tab(t, s);
        expect(find.text('Detail content'), findsOneWidget);
      }
      for (final s in FamilySection.values) expect(initialized[s], 1);
      await tab(t, FamilySection.crew);
      expect(find.text('Detail content'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Section crew'), findsOneWidget);
    },
  );
  testWidgets(
    'Switching tabs preserves drafts, scroll and context, with tickers only for the visible section',
    (t) async {
      await mount(t);
      await tab(t, FamilySection.diary);
      await t.enterText(
        find.byKey(const ValueKey('draft-diary')),
        'Borrador sintético',
      );
      await t.drag(find.byType(ListView), const Offset(0, -550));
      await t.pumpAndSettle();
      final state = t.state<_SectionFixtureState>(
        find.byType(SectionFixture).last,
      );
      final offset = state.scroll.offset;
      expect(offset, greaterThan(200));
      await tab(t, FamilySection.documents);
      expect(find.text('paused-diary', skipOffstage: false), findsOneWidget);
      await tab(t, FamilySection.diary);
      expect(find.text('Borrador sintético'), findsOneWidget);
      expect(state.scroll.offset, offset);
      expectBar(t);
    },
  );
  testWidgets(
    'Back pops the detail, then returns home; rapid repeated selections remain safe',
    (t) async {
      await mount(t);
      await tab(t, FamilySection.documents);
      await t.tap(find.byKey(const ValueKey('detail')));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Section documents'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Section home'), findsOneWidget);
      for (var i = 0; i < 20; i++) {
        await t.tap(find.byKey(const ValueKey('family-tab-gallery')));
      }
      await t.pumpAndSettle();
      expect(initialized[FamilySection.gallery], 1);
      expectBar(t);
    },
  );
  testWidgets('Popup must be resolved before switching; bar stays visible', (
    t,
  ) async {
    await mount(t);
    await t.tap(find.byKey(const ValueKey('modal')));
    await t.pumpAndSettle();
    expectBar(t);
    final button = t.widget<TextButton>(
      find.byKey(const ValueKey('family-tab-map')),
    );
    expect(button.onPressed, isNull);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    await tab(t, FamilySection.map);
    expect(find.text('Section map'), findsOneWidget);
  });
  testWidgets('Timeline pin selects map; returning keeps the diary', (t) async {
    await mount(t);
    await tab(t, FamilySection.diary);
    await t.tap(find.byKey(const ValueKey('pin')));
    await t.pumpAndSettle();
    expect(events, ['pin-910002']);
    expect(find.text('Section map'), findsOneWidget);
    await tab(t, FamilySection.diary);
    expect(initialized[FamilySection.diary], 1);
  });
  testWidgets(
    'Signing out removes all cached sections and the navigation bar',
    (t) async {
      await mount(t);
      await tab(t, FamilySection.crew);
      await tab(t, FamilySection.map);
      await t.tap(find.byKey(const ValueKey('logout')));
      await t.pumpAndSettle();
      expect(find.text('Signed out'), findsOneWidget);
      expect(find.byType(FamilyNavigationBar), findsNothing);
      expect(disposed.toSet(), {
        FamilySection.home,
        FamilySection.crew,
        FamilySection.map,
      });
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(FamilyNavigationBar), findsNothing);
    },
  );
  testWidgets(
    'Medical draft survives section changes and back still asks before discarding',
    (t) async {
      final provider = medical.MedicalFixtureProvider();
      await t.pumpWidget(
        MaterialApp(
          home: FamilyNavigation(
            builders: {
              for (final section in FamilySection.values)
                section: (context) => section == FamilySection.home
                    ? Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            buildPapiRoute(
                              ViewMedicalRecordScreen(
                                login: medical.fixtureLogin,
                                provider: provider,
                              ),
                            ),
                          ),
                          child: const Text('Open medical'),
                        ),
                      )
                    : SectionFixture(section),
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open medical'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('medical-edit')));
      await t.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) => w is MedicalFormField && w.label == 'Nombre y apellido',
      );
      final input = find.descendant(
        of: field,
        matching: find.byType(TextFormField),
      );
      await t.ensureVisible(input);
      await t.pumpAndSettle();
      await t.enterText(input, 'Borrador conservado LAB');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      await tab(t, FamilySection.documents);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Borrador conservado LAB'), findsOneWidget);
      expect(provider.updates, 0);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Seguir editando'), findsOneWidget);
      await t.tap(find.text('Seguir editando'));
      await t.pumpAndSettle();
      expect(find.text('Borrador conservado LAB'), findsOneWidget);
      expectBar(t);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      provider.dispose();
    },
  );

  testWidgets(
    'Changing section closes a drawer instead of retaining an invisible modal',
    (t) async {
      await mount(t);
      final scaffold = t.state<ScaffoldState>(
        find.descendant(
          of: find.byType(SectionFixture),
          matching: find.byType(Scaffold),
        ),
      );
      scaffold.openEndDrawer();
      await t.pumpAndSettle();
      await tab(t, FamilySection.documents);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(scaffold.isEndDrawerOpen, isFalse);
      expectBar(t);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final config in [
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 1.4),
      (const Size(320, 568), 3.0),
    ]) {
      testWidgets(
        'Accessible bar ${platform.name}, ${config.$1.width}, text ${config.$2}',
        (t) async {
          // Test the actual footer on a quiet surface, independently of fixture forms.
          t.view.physicalSize = config.$1;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final semantics = t.ensureSemantics();

          await t.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(
                  size: config.$1,
                  padding: const EdgeInsets.only(bottom: 24),
                  textScaler: TextScaler.linear(config.$2),
                ),
                child: Scaffold(
                  bottomNavigationBar: FamilyNavigationBar(
                    selected: FamilySection.documents,
                    onSelected: (_) {},
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expectBar(t);
          expect(find.bySemanticsLabel('Documentos'), findsOneWidget);
          final bottom = t
              .getBottomRight(find.byKey(const ValueKey('family-tab-gallery')))
              .dy;
          expect(bottom, lessThan(config.$1.height - 24));
          semantics.dispose();
        },
      );
    }
  }
}
