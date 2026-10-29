import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/main.dart';
import 'package:kuyena_tracker/profile/application/profile_controller.dart';
import 'package:kuyena_tracker/profile/domain/user_profile.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import '../data/data_fixture.dart';

void main() {
  // The widget fake clock does not drive native WebCrypto promises. Data tests
  // separately exercise the platform implementation; widget tests use pure Dart.
  Cryptography.instance = DartCryptography.defaultInstance;
  testWidgets(
    'Period hint respects saved time, uses personal estimate and can be dismissed',
    (t) async {
      final f = DataFixture();
      var now = DateTime(2026, 10, 29, 19, 59);
      final diary = PeriodDiary(
        repository: LocalPeriodRepository(f.store.periodStorage),
        dataLock: f.lock,
        clock: () => now,
      );
      final profile = UserProfile(
        completed: true,
        lastPeriodStart: dataToday.addDays(-26),
        exactCycleDays: 28,
        periodReminder: true,
        dailyReminder: false,
        reminderMinute: 1200,
      );
      await f.store.saveProfile(profile, expected: null, today: dataToday);
      final controller = ProfileController(
        store: f.store,
        today: () => dataToday,
      );
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      await t.pumpWidget(
        ZyklusApp(
          diary: diary,
          journal: f.journal,
          profileController: controller,
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Deine nächste Periode wird'), findsNothing);
      now = DateTime(2026, 10, 29, 20, 0);
      await t.pump(const Duration(minutes: 1));
      await t.pumpAndSettle();
      expect(find.textContaining('in etwa 2 Tagen'), findsOneWidget);
      await t.tap(find.byTooltip('Dismiss today'));
      await t.pumpAndSettle();
      expect(find.textContaining('Deine nächste Periode wird'), findsNothing);
    },
  );
}
