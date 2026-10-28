import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';
import '../../periods/domain/calendar_date.dart';

DateTime shiftMonth(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);
int monthRows(DateTime month) =>
    ((DateTime(month.year, month.month, 1).weekday -
                1 +
                DateTime(month.year, month.month + 1, 0).day) /
            7)
        .ceil();

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.onSelect,
    this.selected,
    this.periodDays = const {},
    this.entryDays = const {},
    this.picker = false,
    this.mini = false,
  });
  final DateTime month;
  final CalendarDate today;
  final CalendarDate? selected;
  final ValueChanged<CalendarDate> onSelect;
  final Set<CalendarDate> periodDays, entryDays;
  final bool picker, mini;
  @override
  Widget build(BuildContext context) {
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = monthRows(month);
    return Column(
      children: [
        Row(
          children: [
            for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
              Expanded(
                child: SizedBox(
                  height: picker ? 28 : 18,
                  child: Center(
                    child: Text(
                      mini ? d[0] : d,
                      style: HomeDesign.text(
                        mini ? 8 : 11,
                        color: HomeDesign.muted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: picker ? 4 : 10),
        for (var row = 0; row < rows; row++)
          SizedBox(
            height: mini
                ? 24
                : picker
                ? 46
                : 44,
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = row * 7 + col - offset + 1;
                        if (day < 1 || day > count) {
                          return const SizedBox.shrink();
                        }
                        final date = CalendarDate(month.year, month.month, day);
                        final future = picker && date.compareTo(today) > 0;
                        final isSelected = picker && selected == date;
                        final isPeriod = periodDays.contains(date);
                        final fill = isSelected || isPeriod;
                        return Semantics(
                          label: fullDate(date),
                          selected: selected == date,
                          button: true,
                          child: Tooltip(
                            message: fullDate(date),
                            child: InkWell(
                              key: ValueKey(
                                '${picker ? 'pick' : 'calendar'}-${date.iso}',
                              ),
                              onTap: future ? null : () => onSelect(date),
                              customBorder: const CircleBorder(),
                              child: Center(
                                child: Container(
                                  width: mini ? 23 : 40,
                                  height: mini ? 23 : 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: fill ? HomeDesign.red : null,
                                    border: date == today && !fill
                                        ? Border.all(
                                            color: HomeDesign.red,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Text(
                                        '$day',
                                        style: HomeDesign.text(
                                          mini
                                              ? 9
                                              : picker
                                              ? 14
                                              : 17,
                                          color: fill
                                              ? Colors.white
                                              : future
                                              ? HomeDesign.muted.withValues(
                                                  alpha: 0.45,
                                                )
                                              : HomeDesign.red,
                                          weight: fill
                                              ? FontWeight.w800
                                              : picker
                                              ? FontWeight.w600
                                              : FontWeight.w700,
                                        ),
                                      ),
                                      if (entryDays.contains(date) && !mini)
                                        Positioned(
                                          bottom: 3,
                                          child: Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: fill
                                                  ? Colors.white
                                                  : HomeDesign.red,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class MonthCard extends StatelessWidget {
  const MonthCard({
    super.key,
    required this.month,
    required this.today,
    required this.onSelect,
    this.periodDays = const {},
    this.entryDays = const {},
  });
  final DateTime month;
  final CalendarDate today;
  final ValueChanged<CalendarDate> onSelect;
  final Set<CalendarDate> periodDays, entryDays;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: HomeDesign.palePink,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(monthLabel(month), style: HomeDesign.text(24, height: 1.333333)),
        const SizedBox(height: 14),
        MonthGrid(
          month: month,
          today: today,
          onSelect: onSelect,
          periodDays: periodDays,
          entryDays: entryDays,
        ),
      ],
    ),
  );
}

class MonthArrows extends StatelessWidget {
  const MonthArrows({super.key, required this.month, required this.onChanged});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous month',
        onPressed: month.year == 1 && month.month == 1
            ? null
            : () => onChanged(shiftMonth(month, -1)),
        icon: const DesignAsset('afed9.svg', width: 44, height: 44),
        padding: EdgeInsets.zero,
      ),
      Expanded(
        child: Text(
          monthLabel(month),
          textAlign: TextAlign.center,
          style: HomeDesign.text(22),
        ),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: month.year == 9999 && month.month == 12
            ? null
            : () => onChanged(shiftMonth(month, 1)),
        icon: const DesignAsset('2ccbd.svg', width: 44, height: 44),
        padding: EdgeInsets.zero,
      ),
    ],
  );
}
