import 'package:flutter/material.dart';

import '../application/period_diary.dart';
import '../domain/calendar_date.dart';
import '../domain/period.dart';

/// Edits a draft. Nothing is saved until the person confirms it.
class PeriodEntryDialog extends StatefulWidget {
  const PeriodEntryDialog({
    super.key,
    required this.today,
    required this.onSave,
    this.initial,
  });

  final CalendarDate today;
  final Period? initial;
  final Future<List<Period>> Function(CalendarDate start, CalendarDate? end)
  onSave;

  @override
  State<PeriodEntryDialog> createState() => _PeriodEntryDialogState();
}

class _PeriodEntryDialogState extends State<PeriodEntryDialog> {
  late CalendarDate _start;
  CalendarDate? _end;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start ?? widget.today;
    _end = widget.initial?.end;
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final earliest = isEnd
        ? (_start.compareTo(widget.today) > 0 ? widget.today : _start)
        : CalendarDate(1, 1, 1);
    final candidate = (isEnd ? _end : _start) ?? _start;
    final initial = candidate.compareTo(earliest) < 0
        ? earliest
        : candidate.compareTo(widget.today) > 0
        ? widget.today
        : candidate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.value,
      firstDate: earliest.value,
      lastDate: widget.today.value,
      helpText: isEnd
          ? 'Letzten Periodentag auswählen'
          : 'Ersten Periodentag auswählen',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final date = CalendarDate.fromDateTime(picked);
      if (isEnd) {
        _end = date;
      } else {
        _start = date;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final periods = await widget.onSave(_start, _end);
      if (mounted) Navigator.of(context).pop(periods);
    } on PeriodRuleException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Die Änderung konnte nicht bestätigt werden. '
              'Deine Eingaben bleiben hier stehen. '
              'Bei unklarem Speicherausgang: Abbrechen und den Verlauf neu laden.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          widget.initial == null ? 'Periode eintragen' : 'Periode bearbeiten',
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Beginn',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('period-start-field'),
                onPressed: _saving ? null : () => _pickDate(isEnd: false),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_start.display),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ende (optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('period-end-field'),
                onPressed: _saving ? null : () => _pickDate(isEnd: true),
                icon: const Icon(Icons.event_outlined),
                label: Text(_end?.display ?? 'Datum auswählen'),
              ),
              if (_end != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('period-remove-end'),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _end = null;
                            _error = null;
                          }),
                    icon: const Icon(Icons.close),
                    label: const Text('Ende entfernen'),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Wenn du das Ende noch nicht weißt, lass es offen. '
                'Du kannst es später ergänzen.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const ValueKey('period-save-button'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
