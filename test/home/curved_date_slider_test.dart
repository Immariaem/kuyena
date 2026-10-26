import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/home/presentation/curved_date_slider.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';

Future<void> openWheel(WidgetTester tester, CalendarDate initial) async {
  var selected = initial;
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: StatefulBuilder(
        builder: (context, update) => Scaffold(
          backgroundColor: Colors.red,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 360,
                  child: CurvedDateSlider(
                    selectedDate: selected,
                    onChanged: (date) => update(() => selected = date),
                  ),
                ),
                Text(selected.iso, key: const ValueKey('selected-date-output')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder date(String iso) => find.byKey(ValueKey('date-$iso'));
Finder get slider => find.byKey(const ValueKey('curved-date-slider'));

void main() {
  testWidgets(
    'Ausgewählter Tag steht mittig und höher als seine vier Nachbarn',
    (tester) async {
      await openWheel(tester, CalendarDate(2026, 10, 22));
      for (final iso in [
        '2026-10-20',
        '2026-10-21',
        '2026-10-22',
        '2026-10-23',
        '2026-10-24',
      ]) {
        expect(date(iso), findsOneWidget);
      }
      expect(
        tester.getCenter(date('2026-10-22')).dx,
        closeTo(tester.getCenter(slider).dx, 1),
      );
      final centerTop = tester.getTopLeft(date('2026-10-22')).dy;
      final nearTop = tester.getTopLeft(date('2026-10-21')).dy;
      final farTop = tester.getTopLeft(date('2026-10-20')).dy;
      expect(centerTop, lessThan(nearTop));
      expect(nearTop, lessThan(farTop));
    },
  );

  testWidgets(
    'Wischen rastet beim nächsten Tag ein und verschiebt das ganze Fenster',
    (tester) async {
      await openWheel(tester, CalendarDate(2026, 10, 22));
      await tester.drag(slider, const Offset(-72, 0));
      await tester.pumpAndSettle();
      expect(find.text('2026-10-23'), findsOneWidget);
      expect(date('2026-10-25'), findsOneWidget);
      expect(
        tester.getCenter(date('2026-10-23')).dx,
        closeTo(tester.getCenter(slider).dx, 1),
      );
    },
  );

  testWidgets('Antippen eines Nachbartags bewegt ihn in die Mitte', (
    tester,
  ) async {
    await openWheel(tester, CalendarDate(2026, 10, 22));
    await tester.tap(date('2026-10-23'));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-23'), findsOneWidget);
    expect(
      tester.getCenter(date('2026-10-23')).dx,
      closeTo(tester.getCenter(slider).dx, 1),
    );
  });

  testWidgets('Mausrad wechselt den Tag', (tester) async {
    await openWheel(tester, CalendarDate(2026, 10, 22));
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(slider),
        scrollDelta: const Offset(0, 60),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026-10-23'), findsOneWidget);
  });

  testWidgets('Pfeiltasten wechseln den fokussierten Tag in beide Richtungen', (
    tester,
  ) async {
    await openWheel(tester, CalendarDate(2026, 10, 22));
    await tester.tap(date('2026-10-22'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2026-10-23'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('2026-10-22'), findsOneWidget);
  });

  testWidgets('Tage bleiben über Zeitumstellung und Monatswechsel lückenlos', (
    tester,
  ) async {
    await openWheel(tester, CalendarDate(2026, 3, 28));
    await tester.drag(slider, const Offset(-72, 0));
    await tester.pumpAndSettle();
    expect(find.text('2026-03-29'), findsOneWidget);
    await tester.drag(slider, const Offset(-72, 0));
    await tester.pumpAndSettle();
    expect(find.text('2026-03-30'), findsOneWidget);
    expect(date('2026-04-01'), findsOneWidget);
  });

  testWidgets('Scrollen funktioniert über den Jahreswechsel', (tester) async {
    await openWheel(tester, CalendarDate(2026, 12, 31));
    await tester.drag(slider, const Offset(-72, 0));
    await tester.pumpAndSettle();
    expect(find.text('2027-01-01'), findsOneWidget);
    expect(date('2026-12-30'), findsOneWidget);
    expect(date('2027-01-03'), findsOneWidget);
  });
}
