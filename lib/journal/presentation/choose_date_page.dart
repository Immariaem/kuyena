import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../calendar/presentation/calendar_widgets.dart';
import '../../home/presentation/home_design.dart';
import '../../periods/domain/calendar_date.dart';

class ChooseDatePage extends StatefulWidget {
  const ChooseDatePage({
    super.key,
    required this.today,
    required this.initialDate,
    required this.onContinue,
    required this.onCancel,
    required this.onSelectTab,
    required this.active,
  });
  final CalendarDate today, initialDate;
  final ValueChanged<CalendarDate> onContinue;
  final VoidCallback onCancel;
  final ValueChanged<int> onSelectTab;
  final int active;
  @override
  State<ChooseDatePage> createState() => _ChooseDatePageState();
}

class _ChooseDatePageState extends State<ChooseDatePage> {
  late CalendarDate _date;
  late DateTime _month;
  @override
  void initState() {
    super.initState();
    _date = widget.initialDate.compareTo(widget.today) > 0
        ? widget.today
        : widget.initialDate;
    _month = DateTime(_date.value.year, _date.value.month);
  }

  @override
  Widget build(BuildContext context) => KuyenaPage(
    title: 'Choose a date',
    subtitle: 'Choose the date for your log entry.',
    compactHeader: true,
    headerHeight: 105,
    active: widget.active,
    onSelect: widget.onSelectTab,
    onLog: () => widget.onContinue(_date),
    datePicker: true,
    padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
    trailing: IconButton(
      tooltip: 'Cancel',
      onPressed: widget.onCancel,
      icon: const DesignAsset('d6ebf.svg', width: 20.0015, height: 20.0057),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthArrows(
          month: _month,
          onChanged: (m) => setState(() => _month = m),
        ),
        const SizedBox(height: 8),
        MonthGrid(
          month: _month,
          today: widget.today,
          selected: _date,
          picker: true,
          onSelect: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: 8),
        DateSummary(date: _date, today: widget.today),
        const SizedBox(height: 12),
        DesignButton(
          key: const ValueKey('date-continue'),
          label: 'Continue',
          onPressed: () => widget.onContinue(_date),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: widget.onCancel,
          child: Text('Cancel', style: HomeDesign.text(16)),
        ),
      ],
    ),
  );
}
