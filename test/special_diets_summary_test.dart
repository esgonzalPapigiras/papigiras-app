import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/design/coordinator_home_trial.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';

void main() {
  CoordinatorTourDetail parse(Map<String, dynamic> extra) =>
      CoordinatorTourDetail.fromJson({
        'tourId': 910001,
        'assignmentId': 910001,
        ...extra,
      });

  test(
    'server diet counts are optional; missing and malformed data are not zero',
    () {
      expect(parse({}).specialDietCounts, isNull);
      expect(parse({'specialDietCounts': {}}).specialDietCounts, isEmpty);
      for (final invalid in [
        null,
        [],
        '12',
        {'vegano': -1},
        {'vegano': 1.5},
        {'vegano': 'unknown'},
        {'': 2},
      ]) {
        expect(parse({'specialDietCounts': invalid}).specialDietCounts, isNull);
      }
    },
  );

  test(
    'diet counts preserve received groups, including diets beyond the examples',
    () {
      final result = parse({
        'specialDietCounts': {
          'vegano': 4,
          'vegetariano': 6,
          'celiaco': 1,
          'sin lactosa': 1,
        },
      });
      expect(result.specialDietCounts!.values.fold(0, (a, b) => a + b), 12);
      expect(result.specialDietCounts!['sin lactosa'], 1);
      expect(
        () => result.specialDietCounts!['vegano'] = 99,
        throwsUnsupportedError,
      );
    },
  );

  Future<void> show(
    WidgetTester tester,
    Map<String, int>? counts, {
    double scale = 1,
    required VoidCallback onRoster,
    VoidCallback? onDiets,
  }) async {
    tester.view.physicalSize = const Size(320, 568);
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
        home: AppleDesignTrialScope(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: HomeTrialPassengers(
                  male: 47,
                  female: 61,
                  maleCompanion: 2,
                  femaleCompanion: 4,
                  specialDietCounts: counts,
                  onOpen: onRoster,
                  onOpenDiets: onDiets,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 3.0]) {
    testWidgets(
      'diet row opens passenger list independently from roster at text $scale',
      (tester) async {
        var rosterCalls = 0;
        var dietCalls = 0;
        await show(
          tester,
          {'vegetariano': 6, 'vegano': 4, 'celiaco': 2},
          scale: scale,
          onRoster: () => rosterCalls++,
          onDiets: () => dietCalls++,
        );
        final diet = find.byKey(const ValueKey('home-special-diets'));
        await tester.ensureVisible(diet);
        await tester.pumpAndSettle();
        expect(tester.getSize(diet).height, greaterThanOrEqualTo(48));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('home-special-diets-total')),
              )
              .data,
          '12',
        );
        await tester.tap(diet);
        await tester.pumpAndSettle();
        expect(dietCalls, 1);
        expect(rosterCalls, 0);
        expect(tester.takeException(), isNull);
        final roster = find.byKey(const ValueKey('home-passenger-list'));
        await tester.ensureVisible(roster);
        await tester.pumpAndSettle();
        await tester.tap(roster);
        expect(rosterCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('real zero still opens the passenger list', (tester) async {
    var calls = 0;
    await show(tester, {}, onRoster: () {}, onDiets: () => calls++);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-special-diets-total')))
          .data,
      '0',
    );
    await tester.tap(find.byKey(const ValueKey('home-special-diets')));
    expect(calls, 1);
  });

  testWidgets(
    'older server leaves diets unavailable while roster remains usable',
    (tester) async {
      var calls = 0;
      await show(tester, null, onRoster: () => calls++);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('home-special-diets-total')),
            )
            .data,
        '—',
      );
      await tester.tap(find.byKey(const ValueKey('home-special-diets')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-passenger-list')));
      expect(calls, 1);
    },
  );
}
