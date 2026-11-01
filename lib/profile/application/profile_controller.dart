import 'package:flutter/foundation.dart';
import '../../data/storage/local_app_store.dart';
import '../../periods/domain/calendar_date.dart';
import '../../periods/application/period_timeline.dart';
import '../domain/user_profile.dart';

final class ProfileController extends ChangeNotifier {
  ProfileController({required this.store, required this.today});
  final LocalAppStore store;
  final CalendarDate Function() today;
  UserProfile? value;
  CalendarDate? latestStart, latestEnd;
  bool latestOngoing = false;
  bool legacyReminders = false;
  Future<void> load() async {
    final data = await store.load();
    final next = data.profile;
    final timeline = PeriodTimeline.from(
      periods: data.periods,
      entries: data.journal.entries,
      periodDays: data.journal.periodDays,
      asOf: today(),
    );
    latestStart = timeline.periods.isEmpty
        ? null
        : timeline.periods.first.start;
    latestEnd = timeline.periods.isEmpty ? null : timeline.periods.first.end;
    latestOngoing =
        timeline.periods.isNotEmpty && timeline.periods.first.isOngoing;
    legacyReminders = data.journal.reminders;
    final changed = next?.encode() != value?.encode();
    value = next;
    if (changed) notifyListeners();
  }

  Future<void> save(
    UserProfile profile, {
    required UserProfile? expected,
  }) async {
    await store.saveProfile(profile, expected: expected, today: today());
    value = profile;
    notifyListeners();
  }
}
