import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/home/presentation/home_design.dart';
import 'package:kuyena_tracker/home/presentation/period_status_ring.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/cycle_display.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import 'package:kuyena_tracker/periods/domain/period_day_overview.dart';

CalendarDate d(int n) => CalendarDate(2026, 10, n);
PeriodDayOverview overview(int n, {bool active = false}) =>
    PeriodDayOverview.fromPeriods([
      Period(
        id: '1',
        start: d(1),
        end: active ? null : d(5),
        isOngoing: active,
      ),
    ], d(n));
Widget ring(PeriodDayOverview view) => MaterialApp(
  home: Scaffold(
    body: PeriodStatusRing(
      scale: 1,
      overview: view,
      isToday: true,
      loading: false,
      loadFailed: false,
      onTap: () {},
    ),
  ),
);
PeriodRingPainter painter(WidgetTester t) =>
    t
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is PeriodRingPainter,
              ),
            )
            .painter!
        as PeriodRingPainter;

void main() {
  testWidgets('Whole cycle remains visible and recorded bleeding is red', (
    t,
  ) async {
    await t.pumpWidget(ring(overview(8)));
    await t.pumpAndSettle();
    expect(painter(t).days.length, 28);
    expect(painter(t).days.where((d) => d == CycleDayType.period).length, 5);
    expect(
      painter(t).days.where((d) => d == CycleDayType.estimatedOvulation).length,
      7,
    );
    expect(PeriodRingPainter.colorFor(CycleDayType.period), HomeDesign.red);
    expect(
      PeriodRingPainter.colorFor(CycleDayType.estimatedOvulation),
      HomeDesign.ovulationPink,
    );
    expect(PeriodRingPainter.colorFor(CycleDayType.rest), HomeDesign.cycleRest);
    expect(painter(t).selectedIndex, 7);
    expect(find.text('Noch ca. 5 Tage'), findsOneWidget);
    expect(find.text('Bis zum Eisprungfenster'), findsOneWidget);
  });
  testWidgets('Active period keeps day counter; marker follows selected day', (
    t,
  ) async {
    await t.pumpWidget(ring(overview(3, active: true)));
    expect(find.text('Tag 3'), findsOneWidget);
    expect(painter(t).selectedIndex, 2);
    expect(painter(t).days.take(3), everyElement(CycleDayType.period));
    await t.pumpWidget(ring(overview(1, active: true)));
    expect(find.text('Tag 1'), findsOneWidget);
    expect(painter(t).selectedIndex, 0);
  });
  testWidgets(
    'Window and later countdown change without inventing an exact ovulation day',
    (t) async {
      await t.pumpWidget(ring(overview(13)));
      expect(find.text('Eisprungfenster'), findsOneWidget);
      expect(find.text('Ungefähr jetzt'), findsOneWidget);
      await t.pumpWidget(ring(overview(20)));
      expect(find.text('Bis zur nächsten Periode'), findsOneWidget);
      expect(find.text('Noch ca. 9 Tage'), findsOneWidget);
      await t.pumpWidget(ring(overview(30)));
      expect(find.text('Termin vorbei'), findsOneWidget);
      expect(painter(t).selectedIndex, isNull);
    },
  );
}
