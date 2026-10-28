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
  });
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
  CalendarDate? _dismissedReminder;
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadReminder();
  }

  Future<void> _loadReminder() async {
    try {
      final data = await widget.journal.load();
      if (mounted) setState(() => _journal = data);
    } catch (_) {
      if (mounted) setState(() => _journal = null);
    }
  }

  void _select(int tab) {
    setState(() {
      _tab = tab;
      _revision++;
    });
    _loadReminder();
  }

  Future<void> _history() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PeriodHomePage(diary: widget.diary),
      ),
    );
    if (mounted) {
      setState(() => _revision++);
      _loadReminder();
    }
  }

  Future<void> _log([CalendarDate? date]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LogFlow(
          journal: widget.journal,
          initialDate: date ?? widget.diary.today,
          active: _tab,
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
        diary: widget.diary,
        journal: widget.journal,
        onSelect: _select,
        onLog: _log,
        onHistory: _history,
      ),
      2 => RecommendationsPage(onSelect: _select, onLog: _log),
      3 => CyclePage(
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
        onCalendar: () => _select(1),
        onLog: _log,
        onForYou: () => _select(2),
        onCycle: () => _select(3),
      ),
    };
    final today = widget.diary.today;
    final remind =
        _tab == 0 &&
        _journal?.reminders == true &&
        _journal?.entryFor(today) == null &&
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
                                'A moment for you? Log today when you are ready.',
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
  });
  final DayJournal journal;
  final CalendarDate initialDate;
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
