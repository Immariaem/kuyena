import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';
import '../../journal/application/day_journal.dart';
import '../../journal/domain/day_entry.dart';
import '../../journal/presentation/day_entry_labels.dart';
import '../../periods/application/period_timeline.dart';
import '../../periods/application/period_diary.dart';
import '../../periods/domain/calendar_date.dart';
import '../../periods/domain/period.dart';
import '../../periods/presentation/period_quick_sheet.dart';
import 'calendar_widgets.dart';

enum CalendarView { day, month, year }

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.diary,
    required this.journal,
    required this.onSelect,
    required this.onLog,
    required this.onHistory,
    this.initialDate,
  });
  final CalendarDate? initialDate;
  final PeriodDiary diary;
  final DayJournal journal;
  final ValueChanged<int> onSelect;
  final ValueChanged<CalendarDate> onLog;
  final VoidCallback onHistory;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late CalendarDate _date;
  late DateTime _month;
  CalendarView _view = CalendarView.month;
  List<Period> _periods = [];
  JournalData _journal = JournalData();
  bool _loading = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? widget.diary.today;
    _month = DateTime(_date.value.year, _date.value.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final values = await Future.wait<Object>([
        widget.diary.load(),
        widget.journal.load(),
      ]);
      if (mounted) {
        setState(() {
          _journal = values[1] as JournalData;
          _periods = PeriodTimeline.from(
            periods: values[0] as List<Period>,
            entries: _journal.entries,
            asOf: widget.diary.today,
          ).periods;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _periodDay(CalendarDate d) =>
      _journal.entryFor(d)?.flow != FlowIntensity.none &&
      _periods.any(
        (p) =>
            d == p.start ||
            (p.start.compareTo(d) <= 0 &&
                (p.end != null
                    ? p.end!.compareTo(d) >= 0
                    : p.isOngoing && d.compareTo(widget.diary.today) <= 0)),
      );
  Set<CalendarDate> _days(DateTime m) => {
    for (var day = 1; day <= DateTime(m.year, m.month + 1, 0).day; day++)
      if (_periodDay(CalendarDate(m.year, m.month, day)))
        CalendarDate(m.year, m.month, day),
  };
  void _selectDate(CalendarDate d) => setState(() {
    _date = d;
    _view = CalendarView.day;
  });
  final _selectorKey = GlobalKey();
  String _viewLabel(CalendarView v) => switch (v) {
    CalendarView.day => 'Day',
    CalendarView.month => 'Month',
    CalendarView.year => 'Year',
  };
  Widget _selectorFace({bool open = false}) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: HomeDesign.pink, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DesignAsset('cb0fa.svg', width: 14, height: 14),
        const SizedBox(width: 6),
        Text(_viewLabel(_view), style: HomeDesign.text(12)),
        const SizedBox(width: 6),
        RotatedBox(
          quarterTurns: open ? 2 : 0,
          child: DesignAsset(
            open ? '2564b.svg' : 'c9644.svg',
            width: 12,
            height: 12,
          ),
        ),
      ],
    ),
  );
  Future<void> _showViewMenu() async {
    final box = _selectorKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero),
        size = MediaQuery.sizeOf(context);
    final left = math.max(
      8.0,
      math.min(size.width - 119, origin.dx + box.size.width + 8 - 111),
    );
    final top = math.max(8.0, math.min(size.height - 210, origin.dy - 8));
    final result = await showDialog<CalendarView>(
      context: context,
      barrierColor: Colors.transparent,
      barrierLabel: 'Close calendar view menu',
      useSafeArea: false,
      builder: (menuContext) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: 111,
            child: Material(
              color: HomeDesign.palePink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: HomeDesign.pink, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(menuContext),
                      borderRadius: BorderRadius.circular(99),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _selectorFace(open: true),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: HomeDesign.pink, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (
                            var i = 0;
                            i < CalendarView.values.length;
                            i++
                          ) ...[
                            if (i > 0) const SizedBox(height: 4),
                            SizedBox(
                              height: 42,
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => Navigator.pop(
                                  menuContext,
                                  CalendarView.values[i],
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor:
                                      CalendarView.values[i] == _view
                                      ? HomeDesign.red
                                      : HomeDesign.palePink,
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(
                                  _viewLabel(CalendarView.values[i]),
                                  style: HomeDesign.text(
                                    14,
                                    color: CalendarView.values[i] == _view
                                        ? Colors.white
                                        : HomeDesign.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _view = result);
  }

  Widget _viewSelector() => Semantics(
    button: true,
    label: 'Calendar view ${_viewLabel(_view)}',
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey('calendar-view-selector'),
      onTap: _showViewMenu,
      borderRadius: BorderRadius.circular(99),
      child: KeyedSubtree(key: _selectorKey, child: _selectorFace()),
    ),
  );
  Widget _legend() => Wrap(
    spacing: 18,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DesignAsset('5e2d6.svg', width: 9, height: 9),
          const SizedBox(width: 6),
          Text('Period', style: HomeDesign.text(11, weight: FontWeight.w700)),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DesignAsset('a04ee.svg', width: 9, height: 9),
          const SizedBox(width: 6),
          Text(
            'Today · ${widget.diary.today.value.day} ${monthNames[widget.diary.today.value.month - 1].substring(0, 3)}',
            style: HomeDesign.text(11, weight: FontWeight.w700),
          ),
        ],
      ),
      if (_journal.entries.any((e) => e.hasWellbeing))
        Text(
          '• Day entry',
          style: HomeDesign.text(11, weight: FontWeight.w700),
        ),
    ],
  );
  Widget _months() {
    const center = ValueKey('current-month');
    final before = (_month.year - 1) * 12 + _month.month - 1;
    final after = (9999 - _month.year) * 12 + 13 - _month.month;
    Widget card(int offset) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: MonthCard(
        month: shiftMonth(_month, offset),
        today: widget.diary.today,
        onSelect: _selectDate,
        periodDays: _days(shiftMonth(_month, offset)),
        entryDays: _journal.entries
            .where((e) => e.hasWellbeing)
            .map((e) => e.date)
            .toSet(),
      ),
    );
    return CustomScrollView(
      key: ValueKey('months-${_month.year}-${_month.month}'),
      center: center,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => card(-i - 1),
            childCount: before,
          ),
        ),
        SliverList(
          key: center,
          delegate: SliverChildBuilderDelegate(
            (context, i) => card(i),
            childCount: after,
          ),
        ),
      ],
    );
  }

  Future<void> _periodEntry() async {
    final result = await showPeriodQuickEntry(
      context,
      diary: widget.diary,
      journal: widget.journal,
      date: _date,
    );
    if (!mounted) return;
    if (result == PeriodQuickResult.calendar) {
      setState(() {
        _month = DateTime(_date.value.year, _date.value.month);
        _view = CalendarView.month;
      });
    } else if (result == PeriodQuickResult.saved) {
      await _load();
    }
  }

  Widget _day() {
    final entry = _journal.entryFor(_date);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                onPressed:
                    _date.value.year == 1 &&
                        _date.value.month == 1 &&
                        _date.value.day == 1
                    ? null
                    : () => setState(() => _date = _date.addDays(-1)),
                icon: const Icon(Icons.chevron_left, color: HomeDesign.red),
              ),
              Expanded(
                child: Text(
                  fullDate(_date),
                  textAlign: TextAlign.center,
                  style: HomeDesign.text(18),
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                onPressed:
                    _date.value.year == 9999 &&
                        _date.value.month == 12 &&
                        _date.value.day == 31
                    ? null
                    : () => setState(() => _date = _date.addDays(1)),
                icon: const Icon(Icons.chevron_right, color: HomeDesign.red),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HomeDesign.palePink,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _periodDay(_date) ? 'Period recorded' : 'No period recorded',
                  style: HomeDesign.text(20),
                ),
                if (entry?.flow != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Flow: ${flowLabel(entry!.flow!)}',
                    style: HomeDesign.text(14),
                  ),
                ],
                const SizedBox(height: 12),
                DesignButton(
                  key: const ValueKey('calendar-period-action'),
                  label: 'Periode eintragen / beenden',
                  onPressed: _date.compareTo(widget.diary.today) > 0
                      ? null
                      : _periodEntry,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HomeDesign.palePink,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Your wellbeing', style: HomeDesign.text(20)),
                const SizedBox(height: 10),
                Text(
                  entry?.hasWellbeing != true
                      ? 'No day entry yet.'
                      : [
                          if (entry!.symptoms.isNotEmpty)
                            'Symptoms: ${entry.symptoms.map(symptomLabel).join(', ')}',
                          if (entry.mood != null)
                            'Mood: ${moodLabel(entry.mood!)}',
                          if (entry.energy != null)
                            'Energy: ${entry.energy}/100',
                          if (entry.note.isNotEmpty) entry.note,
                        ].join('\n'),
                  style: HomeDesign.text(
                    15,
                    color: HomeDesign.ink,
                    weight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                DesignButton(
                  label: entry?.hasWellbeing != true
                      ? 'Log this day'
                      : 'Edit day entry',
                  onPressed: _date.compareTo(widget.diary.today) > 0
                      ? null
                      : () => widget.onLog(_date),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onHistory,
            child: Text('Manage period dates', style: HomeDesign.text(15)),
          ),
        ],
      ),
    );
  }

  Widget _year() => ListView(
    children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Previous year',
            onPressed: _month.year <= 1
                ? null
                : () => setState(
                    () => _month = DateTime(_month.year - 1, _month.month),
                  ),
            icon: const Icon(Icons.chevron_left, color: HomeDesign.red),
          ),
          Expanded(
            child: Text(
              '${_month.year}',
              textAlign: TextAlign.center,
              style: HomeDesign.text(24),
            ),
          ),
          IconButton(
            tooltip: 'Next year',
            onPressed: _month.year >= 9999
                ? null
                : () => setState(
                    () => _month = DateTime(_month.year + 1, _month.month),
                  ),
            icon: const Icon(Icons.chevron_right, color: HomeDesign.red),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var m = 1; m <= 12; m++)
              SizedBox(
                width: (c.maxWidth - 12) / 2,
                child: Material(
                  color: HomeDesign.palePink,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    key: ValueKey('year-month-$m'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() {
                      _month = DateTime(_month.year, m);
                      _view = CalendarView.month;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(monthNames[m - 1], style: HomeDesign.text(14)),
                          const SizedBox(height: 8),
                          IgnorePointer(
                            child: MonthGrid(
                              month: DateTime(_month.year, m),
                              today: widget.diary.today,
                              onSelect: (_) {},
                              mini: true,
                              periodDays: _days(DateTime(_month.year, m)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => KuyenaPage(
    title: 'Calendar',
    subtitle: _view == CalendarView.year
        ? '${_month.year}'
        : monthLabel(_month),
    active: 1,
    onSelect: widget.onSelect,
    onLog: () => widget.onLog(_date),
    trailing: _viewSelector(),
    scroll: false,
    padding: const EdgeInsets.fromLTRB(26, 24, 26, 12),
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? Column(
            children: [
              Text(
                'Could not load your calendar. Existing data has not been changed.',
                style: HomeDesign.text(16),
              ),
              const SizedBox(height: 16),
              DesignButton(label: 'Try again', onPressed: _load),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Align(alignment: Alignment.centerLeft, child: _legend()),
              ),
              Expanded(
                child: switch (_view) {
                  CalendarView.month => _months(),
                  CalendarView.day => _day(),
                  CalendarView.year => _year(),
                },
              ),
            ],
          ),
  );
}
