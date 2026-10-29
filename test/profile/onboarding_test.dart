import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/main.dart';
import 'package:kuyena_tracker/profile/application/profile_controller.dart';
import 'package:kuyena_tracker/profile/domain/user_profile.dart';
import 'package:kuyena_tracker/profile/presentation/onboarding_flow.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/journal/presentation/day_entry_page.dart';
import '../data/data_fixture.dart';

void main() {
  // The widget fake clock does not drive native WebCrypto promises. Data tests
  // separately exercise the platform implementation; widget tests use pure Dart.
  Cryptography.instance = DartCryptography.defaultInstance;
  late DataFixture f;
  late ProfileController controller;
  void init() {
    f = DataFixture();
    controller = ProfileController(store: f.store, today: () => dataToday);
  }

  Future<void> open(WidgetTester t, {Size size = const Size(412, 917)}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ZyklusApp(
        key: UniqueKey(),
        diary: f.diary,
        journal: f.journal,
        profileController: controller,
        backupService: f.service(),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> next(WidgetTester t) async =>
      tap(t, find.byKey(const ValueKey('onboarding-next')));
  testWidgets(
    'Welcome, accessible privacy, all optional steps and completion survive reopening',
    (t) async {
      init();
      await open(t);
      expect(find.text('Willkommen'), findsOneWidget);
      await next(t);
      await tap(t, find.text('Unsere Datenschutzinformationen'));
      expect(find.text('Datenschutzinformationen'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await next(t);
      expect(find.text('Zyklusdaten'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await next(t);
      }
      expect(find.text('Zusammenfassung'), findsOneWidget);
      expect(find.text('App starten'), findsOneWidget);
      await next(t);
      expect(find.byType(OnboardingFlow), findsNothing);
      expect((await f.store.load()).profile!.completed, isTrue);
      expect((await f.store.load()).periods, isEmpty);
      await open(t);
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.byKey(const ValueKey('period-status-ring')), findsOneWidget);
    },
  );
  testWidgets(
    'Answers, multi-select, unknown, text, time and summary edits persist without inventing an end',
    (t) async {
      init();
      await f.store.saveProfile(
        UserProfile(step: 2),
        expected: null,
        today: dataToday,
      );
      await open(t);
      await tap(t, find.byKey(const ValueKey('profile-start-date')));
      await tap(
        t,
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.text('20'),
            )
            .last,
      );
      await tap(
        t,
        find.text(
          MaterialLocalizations.of(
            t.element(find.byType(DatePickerDialog)),
          ).okButtonLabel,
        ),
      );
      await tap(t, find.byKey(const ValueKey('profile-periodLength-medium')));
      await t.enterText(
        find.byKey(const ValueKey('profile-exact-cycle')),
        '30',
      );
      await next(t);
      await tap(t, find.byKey(const ValueKey('profile-goal-understand')));
      await tap(t, find.byKey(const ValueKey('profile-goal-patterns')));
      await next(t);
      await tap(t, find.byKey(const ValueKey('profile-symptoms-bloating')));
      await tap(t, find.byKey(const ValueKey('profile-symptoms-fatigue')));
      await tap(t, find.byKey(const ValueKey('profile-trackMoodEnergy-false')));
      await tap(t, find.byKey(const ValueKey('profile-trackNotes-true')));
      await next(t);
      await tap(t, find.byKey(const ValueKey('profile-movements-walking')));
      await t.ensureVisible(find.byKey(const ValueKey('profile-limitations')));
      await t.enterText(
        find.byKey(const ValueKey('profile-limitations')),
        'Keine Sprünge',
      );
      await next(t);
      await tap(t, find.byKey(const ValueKey('profile-diet-vegan')));
      await tap(t, find.byKey(const ValueKey('profile-allergies-none')));
      await tap(t, find.byKey(const ValueKey('profile-allergies-nuts')));
      await t.ensureVisible(
        find.byKey(const ValueKey('profile-dislikedIngredients')),
      );
      await t.enterText(
        find.byKey(const ValueKey('profile-dislikedIngredients')),
        'Pilze',
      );
      await next(t);
      await tap(t, find.byKey(const ValueKey('profile-dailyReminder-true')));
      await tap(t, find.byKey(const ValueKey('profile-reminder-time')));
      final timeFields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await t.enterText(timeFields.at(0), '18');
      await t.enterText(timeFields.at(1), '35');
      await tap(
        t,
        find.text(
          MaterialLocalizations.of(
            t.element(find.byType(TimePickerDialog)),
          ).okButtonLabel,
        ),
      );
      await next(t);
      await tap(t, find.byKey(const ValueKey('profile-summary-3')));
      expect(find.text('Ziele & Interessen'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('profile-goal-symptoms')));
      await next(t);
      expect(find.text('Zusammenfassung'), findsOneWidget);
      await next(t);
      final data = await f.store.load(),
          profile = (await f.store.load()).profile!;
      expect(profile.exactCycleDays, 30);
      expect(profile.goals, {'understand', 'patterns', 'symptoms'});
      expect(profile.symptoms, {Symptom.bloating, Symptom.fatigue});
      expect(profile.trackMoodEnergy, isFalse);
      expect(profile.trackNotes, isTrue);
      expect(profile.limitations, 'Keine Sprünge');
      expect(profile.diet, 'vegan');
      expect(profile.allergies, {'nuts'});
      expect(profile.dislikedIngredients, 'Pilze');
      expect(profile.dailyReminder, isTrue);
      expect(profile.reminderMinute, 1115);
      expect(data.periods.single.start, dataToday.addDays(-9));
      expect(data.periods.single.end, isNull);
      expect(data.periods.single.isOngoing, isFalse);
      expect(find.text('Noch ca. 21 Tage'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Draft resumes at the next step; settings save and cancel keep diary intact',
    (t) async {
      init();
      await open(t);
      await next(t);
      await next(t);
      await tap(t, find.byKey(const ValueKey('profile-cycleLength-medium')));
      await next(t);
      await open(t);
      expect(find.text('Ziele & Interessen'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await next(t);
      }
      await next(t);
      await tap(t, find.byKey(const ValueKey('home-nav-Cycle')));
      await tap(
        t,
        find.byKey(const ValueKey('cycle-Deine Angaben & Einstellungen')),
      );
      await tap(t, find.byKey(const ValueKey('profile-summary-6')));
      await tap(t, find.byKey(const ValueKey('profile-diet-vegetarian')));
      await next(t);
      await next(t);
      expect((await f.store.load()).profile!.diet, 'vegetarian');
      await tap(
        t,
        find.byKey(const ValueKey('cycle-Deine Angaben & Einstellungen')),
      );
      await tap(t, find.byKey(const ValueKey('profile-summary-6')));
      await tap(t, find.byKey(const ValueKey('profile-diet-vegan')));
      await tap(t, find.text('Abbrechen'));
      await tap(t, find.text('Verwerfen'));
      expect((await f.store.load()).profile!.diet, 'vegetarian');
      expect((await f.store.load()).periods, isEmpty);
    },
  );
  testWidgets(
    'Phones, desktop, short viewport and enlarged text show usable setup without overflow',
    (t) async {
      init();
      for (final size in [
        const Size(320, 568),
        const Size(412, 917),
        const Size(1440, 1000),
      ]) {
        t.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        controller = ProfileController(store: f.store, today: () => dataToday);
        await open(t, size: size);
        expect(t.takeException(), isNull);
        await next(t);
        await next(t);
        for (var i = 0; i < 6; i++) {
          expect(t.takeException(), isNull);
          await next(t);
        }
        expect(find.text('App starten'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        await f.store.clear();
      }
    },
  );
  testWidgets(
    'Tracking preferences keep previously saved observations and expose extra symptoms',
    (t) async {
      init();
      await f.journal.saveWellbeing(
        DayEntry(
          date: dataToday,
          symptoms: {Symptom.headache},
          mood: Mood.good,
          energy: 0,
          note: 'Keep',
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: DayEntryPage(
            active: 0,
            date: dataToday,
            journal: f.journal,
            profile: UserProfile(
              symptoms: {Symptom.bloating},
              trackMoodEnergy: false,
              trackNotes: false,
            ),
            onSelectTab: (_) {},
            onBack: () {},
            onSaved: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('symptom-headache')), findsOneWidget);
      expect(find.byKey(const ValueKey('symptom-bloating')), findsOneWidget);
      expect(find.byKey(const ValueKey('symptom-cramps')), findsNothing);
      await tap(t, find.byKey(const ValueKey('show-all-symptoms')));
      expect(find.byKey(const ValueKey('symptom-cramps')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('energy-slider')), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('symptom-bloating')));
      await tap(t, find.byKey(const ValueKey('save-day-entry')));
      final e = (await f.journal.load()).entries.single;
      expect(e.note, 'Keep');
      expect(e.mood, Mood.good);
      expect(e.energy, 0);
      expect(e.symptoms, {Symptom.headache, Symptom.bloating});
    },
  );
}
