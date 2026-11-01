import 'package:flutter/material.dart';
import 'period_day_drag_selection.dart';
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
    this.ovulationDays = const {},
    this.fertileDays = const {},
    this.expectedPeriodDays = const {},
    this.picker = false,
    this.mini = false,
    this.periodEditing = false,
    this.onRangeStart,
    this.onRangeUpdate,
    this.onRangeEnd,
    this.onRangeCancel,
  });
  final DateTime month;
  final CalendarDate today;
  final CalendarDate? selected;
  final ValueChanged<CalendarDate> onSelect;
  final Set<CalendarDate> periodDays,
      entryDays,
      ovulationDays,
      fertileDays,
      expectedPeriodDays;
  final bool picker, mini, periodEditing;
  final ValueChanged<CalendarDate>? onRangeStart, onRangeUpdate;
  final VoidCallback? onRangeEnd, onRangeCancel;
  @override
  Widget build(BuildContext context) {
    final visibleFertile = fertileDays
        .union(ovulationDays)
        .difference(periodDays)
        .difference(expectedPeriodDays);
    final visibleExpected = expectedPeriodDays.difference(periodDays);
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = monthRows(month);
    final dayRows = Column(
      children: [
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
                        final future =
                            (picker || periodEditing) &&
                            date.compareTo(today) > 0;
                        final isSelected = picker && selected == date;
                        final isPeriod = periodDays.contains(date);
                        final fill = isSelected || isPeriod;
                        final isOvulation =
                            !picker &&
                            !periodEditing &&
                            !isPeriod &&
                            ovulationDays.contains(date);
                        final isExpected =
                            !picker &&
                            !periodEditing &&
                            !isPeriod &&
                            expectedPeriodDays.contains(date);
                        final isFertile =
                            !picker &&
                            !periodEditing &&
                            !isPeriod &&
                            !isExpected &&
                            fertileDays.contains(date);
                        final bandDays = isPeriod
                            ? periodDays
                            : isExpected
                            ? visibleExpected
                            : visibleFertile;
                        final connectedLeft =
                            !picker &&
                            (isPeriod ||
                                isOvulation ||
                                isFertile ||
                                isExpected) &&
                            col > 0 &&
                            day > 1 &&
                            bandDays.contains(date.addDays(-1));
                        final connectedRight =
                            !picker &&
                            (isPeriod ||
                                isOvulation ||
                                isFertile ||
                                isExpected) &&
                            col < 6 &&
                            day < count &&
                            bandDays.contains(date.addDays(1));
                        final connected = connectedLeft || connectedRight;
                        final diameter = mini ? 23.0 : 40.0;
                        return Semantics(
                          label:
                              '${fullDate(date)}${isPeriod && !picker
                                  ? ', Periodentag'
                                  : isOvulation
                                  ? ', geschätztes Eisprungfenster'
                                  : isExpected
                                  ? ', geschätzte Periode'
                                  : isFertile
                                  ? ', möglicherweise fruchtbare Zeit, geschätzt'
                                  : ''}',
                          selected: periodEditing ? isPeriod : selected == date,
                          enabled: !future,
                          button: true,
                          child: Tooltip(
                            message: fullDate(date),
                            triggerMode: periodEditing
                                ? TooltipTriggerMode.manual
                                : null,
                            child: InkWell(
                              key: ValueKey(
                                '${picker ? 'pick' : 'calendar'}-${date.iso}',
                              ),
                              onTap: future ? null : () => onSelect(date),
                              customBorder: const CircleBorder(),
                              child: Center(
                                child: Container(
                                  key: isPeriod && !picker
                                      ? ValueKey('period-band-${date.iso}')
                                      : isOvulation
                                      ? ValueKey(
                                          'estimated-ovulation-${date.iso}',
                                        )
                                      : isExpected
                                      ? ValueKey('estimated-period-${date.iso}')
                                      : isFertile
                                      ? ValueKey(
                                          'estimated-fertile-${date.iso}',
                                        )
                                      : null,
                                  width: connected ? double.infinity : diameter,
                                  height: diameter,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.horizontal(
                                      left: connectedLeft
                                          ? Radius.zero
                                          : Radius.circular(diameter / 2),
                                      right: connectedRight
                                          ? Radius.zero
                                          : Radius.circular(diameter / 2),
                                    ),
                                    color: fill
                                        ? HomeDesign.red
                                        : isExpected
                                        ? HomeDesign.predictedPeriod
                                        : isOvulation
                                        ? HomeDesign.ovulationPink
                                        : isFertile
                                        ? HomeDesign.pink
                                        : null,
                                    border: isExpected
                                        ? Border(
                                            top: const BorderSide(
                                              color: HomeDesign.red,
                                              width: 1,
                                            ),
                                            bottom: const BorderSide(
                                              color: HomeDesign.red,
                                              width: 1,
                                            ),
                                            left: BorderSide(
                                              color: HomeDesign.red,
                                              width: 1,
                                              style: connectedLeft
                                                  ? BorderStyle.none
                                                  : BorderStyle.solid,
                                            ),
                                            right: BorderSide(
                                              color: HomeDesign.red,
                                              width: 1,
                                              style: connectedRight
                                                  ? BorderStyle.none
                                                  : BorderStyle.solid,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (date == today && !picker)
                                        Container(
                                          key: ValueKey(
                                            'calendar-today-${date.iso}',
                                          ),
                                          width: diameter - (mini ? 3 : 6),
                                          height: diameter - (mini ? 3 : 6),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            border: Border.all(
                                              color: HomeDesign.pink,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                      if (isExpected && !mini)
                                        Positioned(
                                          bottom: 1,
                                          child: Text(
                                            '≈',
                                            style: HomeDesign.text(9),
                                          ),
                                        ),
                                      Text(
                                        '$day',
                                        style: HomeDesign.text(
                                          mini
                                              ? 9
                                              : picker
                                              ? 14
                                              : 17,
                                          color: date == today && !picker
                                              ? HomeDesign.ink
                                              : fill
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
                                              color: date == today && !picker
                                                  ? HomeDesign.red
                                                  : fill
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
        if (periodEditing && !mini && !picker && onRangeStart != null)
          PeriodDayDragSelection(
            key: ValueKey('period-drag-${month.year}-${month.month}'),
            month: month,
            today: today,
            onStart: onRangeStart!,
            onUpdate: onRangeUpdate!,
            onEnd: onRangeEnd!,
            onCancel: onRangeCancel!,
            child: dayRows,
          )
        else
          dayRows,
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
    this.ovulationDays = const {},
    this.fertileDays = const {},
    this.expectedPeriodDays = const {},
    this.periodEditing = false,
    this.onRangeStart,
    this.onRangeUpdate,
    this.onRangeEnd,
    this.onRangeCancel,
  });
  final bool periodEditing;
  final ValueChanged<CalendarDate>? onRangeStart, onRangeUpdate;
  final VoidCallback? onRangeEnd, onRangeCancel;
  final DateTime month;
  final CalendarDate today;
  final ValueChanged<CalendarDate> onSelect;
  final Set<CalendarDate> periodDays,
      entryDays,
      ovulationDays,
      fertileDays,
      expectedPeriodDays;
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
          ovulationDays: ovulationDays,
          fertileDays: fertileDays,
          expectedPeriodDays: expectedPeriodDays,
          periodEditing: periodEditing,
          onRangeStart: onRangeStart,
          onRangeUpdate: onRangeUpdate,
          onRangeEnd: onRangeEnd,
          onRangeCancel: onRangeCancel,
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
