import 'dart:async';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/user_profile.dart';
import '../../periods/domain/cycle_estimate.dart';
import '../../periods/application/period_timeline.dart';
import '../../data/application/data_backup_service.dart';
import '../../data/backup/backup_files.dart';
import 'package:flutter/material.dart';
import '../../calendar/presentation/calendar_page.dart';
import '../../cycle/presentation/cycle_page.dart';
import '../../home/presentation/home_design.dart';
import '../../home/presentation/kuyena_home_page.dart';
import '../../journal/application/day_journal.dart';
import '../../journal/domain/day_entry.dart';
import '../../journal/presentation/choose_date_page.dart';
import '../../journal/presentation/day_entry_page.dart';
import '../../periods/application/period_diary.dart';
import '../../periods/domain/calendar_date.dart';
import '../../periods/presentation/period_home_page.dart';
import '../../recommendations/presentation/recommendations_page.dart';
import 'kuyena_splash.dart';
import 'kuyena_components.dart';

class KuyenaShell extends StatefulWidget {
  const KuyenaShell({
    super.key,
    required this.diary,
    required this.journal,
    this.showSplash = false,
    this.backupService,
    this.backupFiles,
    this.profileController,
  });
  final DataBackupService? backupService;
  final BackupFiles? backupFiles;
  final ProfileController? profileController;
  final PeriodDiary diary;
  final DayJournal journal;
  final bool showSplash;
  @override
  State<KuyenaShell> createState() => _KuyenaShellState();
}

class _KuyenaShellState extends State<KuyenaShell> with WidgetsBindingObserver {
  int _tab = 0, _revision = 0;
  late bool _splash;
  JournalData? _journal;
  Timer? _reminderTimer;
  int? _periodDue;
  CalendarDate? _dismissedReminder;
  CalendarDate? _calendarInitialDate;
  @override
  void initState() {
    super.initState();
    _splash = widget.showSplash;
    WidgetsBinding.instance.addObserver(this);
    _loadReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadReminder();
  }

  Future<void> _loadReminder() async {
    try {
      await widget.profileController?.load();
      final data = await widget.journal.load();
      final periods = await widget.diary.load();
      final timeline = PeriodTimeline.from(
        periods: periods,
        entries: data.entries,
        periodDays: data.periodDays,
        asOf: widget.diary.today,
      );
      final estimate = CycleEstimate.fromPeriods(
        timeline.periods,
        initialLength: widget.profileController?.value?.exactCycleDays,
      );
      final latest = timeline.periods.isEmpty ? null : timeline.periods.first;
      if (mounted) {
        setState(() {
          _journal = data;
          _periodDue = latest?.isOngoing == true
              ? null
              : estimate == null
              ? null
              : widget.diary.today.daysUntil(estimate.expectedStart);
        });
      }
      _scheduleReminder();
    } catch (_) {
      if (mounted) setState(() => _journal = null);
    }
  }

  bool get _reminderTimeReached {
    final profile = widget.profileController?.value;
    if (profile == null) return true;
    final now = widget.diary.clock();
    return now.hour * 60 + now.minute >= profile.reminderMinute;
  }

  void _scheduleReminder() {
    _reminderTimer?.cancel();
    final profile = widget.profileController?.value;
    if (profile == null || !mounted) return;
    final now = widget.diary.clock(), minute = profile.reminderMinute;
    var due = DateTime(now.year, now.month, now.day, minute ~/ 60, minute % 60);
    if (!due.isAfter(now)) {
      due = DateTime(
        now.year,
        now.month,
        now.day + 1,
        minute ~/ 60,
        minute % 60,
      );
    }
    _reminderTimer = Timer(due.difference(now), () {
      if (mounted) _loadReminder();
    });
  }

  void _select(int tab, {CalendarDate? calendarDate}) {
    setState(() {
      _tab = tab;
      _calendarInitialDate = calendarDate;
      _revision++;
    });
    _loadReminder();
  }

  Future<void> _history() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            PeriodHomePage(diary: widget.diary, journal: widget.journal),
      ),
    );
    if (mounted) {
      setState(() => _revision++);
      _loadReminder();
    }
  }

  Future<void> _log([CalendarDate? date]) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LogFlow(
          journal: widget.journal,
          initialDate: date ?? widget.diary.today,
          active: _tab,
          profile: widget.profileController?.value,
          onSelectTab: _select,
        ),
      ),
    );
    if (mounted) {
      setState(() => _revision++);
      _loadReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_splash) {
      return KuyenaSplash(onFinished: () => setState(() => _splash = false));
    }
    final page = switch (_tab) {
      1 => CalendarPage(
        key: ValueKey('calendar-$_revision'),
        initialDate: _calendarInitialDate,
        diary: widget.diary,
        journal: widget.journal,
        onSelect: _select,
        onLog: _log,
        onHistory: _history,
      ),
      2 => RecommendationsPage(onSelect: _select, onLog: _log),
      3 => CyclePage(
        backupService: widget.backupService,
        backupFiles: widget.backupFiles,
        profileController: widget.profileController,
        key: ValueKey('cycle-$_revision'),
        diary: widget.diary,
        journal: widget.journal,
        onSelect: _select,
        onLog: _log,
        onHistory: _history,
      ),
      _ => KuyenaHomePage(
        key: ValueKey('home-$_revision'),
        diary: widget.diary,
        journal: widget.journal,
        onCalendar: (date) => _select(1, calendarDate: date),
        onLog: _log,
        onForYou: () => _select(2),
        onCycle: () => _select(3),
        initialCycleLength: widget.profileController?.value?.exactCycleDays,
      ),
    };
    final today = widget.diary.today;
    final periodReminder =
        widget.profileController?.value?.periodReminder == true &&
        _periodDue != null &&
        _periodDue! >= 0 &&
        _periodDue! <= 2;
    final remind =
        _tab == 0 &&
        _reminderTimeReached &&
        (periodReminder ||
            (_journal?.reminders == true &&
                _journal?.entryFor(today)?.hasWellbeing != true)) &&
        _dismissedReminder != today;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(0);
      },
      child: Stack(
        children: [
          page,
          if (remind)
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.sizeOf(context).width >= 900 ? 24 : 148,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Material(
                      elevation: 4,
                      color: HomeDesign.palePink,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                periodReminder
                                    ? 'Deine nächste Periode wird ${_periodDue == 0 ? 'ungefähr heute' : 'in etwa $_periodDue Tagen'} erwartet. Die Schätzung kann abweichen.'
                                    : 'Ein Moment für dich? Du kannst deinen Tag jetzt eintragen.',
                                style: HomeDesign.text(14),
                              ),
                            ),
                            TextButton(
                              onPressed: _log,
                              child: Text('Log', style: HomeDesign.text(14)),
                            ),
                            IconButton(
                              tooltip: 'Dismiss today',
                              onPressed: () =>
                                  setState(() => _dismissedReminder = today),
                              icon: const Icon(
                                Icons.close,
                                color: HomeDesign.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogFlow extends StatefulWidget {
  const _LogFlow({
    required this.journal,
    required this.initialDate,
    required this.active,
    required this.onSelectTab,
    this.profile,
  });
  final DayJournal journal;
  final CalendarDate initialDate;
  final UserProfile? profile;
  final int active;
  final ValueChanged<int> onSelectTab;
  @override
  State<_LogFlow> createState() => _LogFlowState();
}

class _LogFlowState extends State<_LogFlow> {
  late CalendarDate _date;
  bool _editing = false;
  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  void _tab(int i) {
    Navigator.pop(context);
    widget.onSelectTab(i);
  }

  @override
  Widget build(BuildContext context) => _editing
      ? DayEntryPage(
          key: ValueKey(_date.iso),
          date: _date,
          profile: widget.profile,
          journal: widget.journal,
          active: widget.active,
          onSelectTab: _tab,
          onBack: () => setState(() => _editing = false),
          onSaved: () {
            Navigator.pop(context);
            showDesignNotice(context, 'Day entry updated.');
          },
        )
      : ChooseDatePage(
          today: widget.journal.today,
          initialDate: _date,
          active: widget.active,
          onSelectTab: _tab,
          onContinue: (d) => setState(() {
            _date = d;
            _editing = true;
          }),
          onCancel: () => Navigator.pop(context),
        );
}
