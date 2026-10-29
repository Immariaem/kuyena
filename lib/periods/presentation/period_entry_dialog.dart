import 'package:flutter/material.dart';

import '../../home/presentation/home_design.dart';
import '../../app/presentation/kuyena_components.dart';

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
  final Future<List<Period>> Function(
    CalendarDate start,
    CalendarDate? end,
    bool isOngoing,
  )
  onSave;

  @override
  State<PeriodEntryDialog> createState() => _PeriodEntryDialogState();
}

class _PeriodEntryDialogState extends State<PeriodEntryDialog> {
  late CalendarDate _start;
  CalendarDate? _end;
  bool _isOngoing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start ?? widget.today;
    _end = widget.initial?.end;
    _isOngoing = widget.initial?.isOngoing ?? false;
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: HomeDesign.red),
          textTheme: Theme.of(
            context,
          ).textTheme.apply(fontFamily: 'NunitoSans'),
        ),
        child: child!,
      ),
      helpText: isEnd
          ? 'Letzten Periodentag auswählen'
          : 'Ersten Periodentag auswählen',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final date = CalendarDate.fromDateTime(picked);
      if (isEnd) {
        _end = date;
        _isOngoing = false;
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
      final periods = await widget.onSave(_start, _end, _isOngoing);
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        titleTextStyle: HomeDesign.text(24),
        contentTextStyle: HomeDesign.text(
          14,
          color: HomeDesign.muted,
          weight: FontWeight.w600,
          height: 1.5,
        ),
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
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontWeight: FontWeight.w800,
                  color: HomeDesign.red,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('period-start-field'),
                onPressed: _saving ? null : () => _pickDate(isEnd: false),
                style: OutlinedButton.styleFrom(
                  textStyle: HomeDesign.text(15),
                  backgroundColor: HomeDesign.palePink,
                  foregroundColor: HomeDesign.red,
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                icon: const DesignAsset('6ad9e.svg', width: 22, height: 22),
                label: Text(_start.display),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                key: const ValueKey('period-ongoing-switch'),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: HomeDesign.red,
                activeThumbColor: Colors.white,
                inactiveTrackColor: HomeDesign.pink,
                inactiveThumbColor: Colors.white,
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                title: Text('Periode läuft noch', style: HomeDesign.text(16)),
                value: _isOngoing,
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _isOngoing = value;
                        if (value) _end = null;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ende (optional)',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontWeight: FontWeight.w800,
                  color: HomeDesign.red,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('period-end-field'),
                onPressed: _saving ? null : () => _pickDate(isEnd: true),
                style: OutlinedButton.styleFrom(
                  textStyle: HomeDesign.text(15),
                  backgroundColor: HomeDesign.palePink,
                  foregroundColor: HomeDesign.red,
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                icon: const DesignAsset('6ad9e.svg', width: 22, height: 22),
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
                'Aktuell noch Blutung? Aktiviere „Periode läuft noch“. '
                'Ist das Ende nur unbekannt, lass das Enddatum offen. '
                'Ein Enddatum beendet die Markierung.',
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
            child: Text('Abbrechen', style: HomeDesign.text(14)),
          ),
          FilledButton(
            key: const ValueKey('period-save-button'),
            style: FilledButton.styleFrom(
              backgroundColor: HomeDesign.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(130, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Speichern',
                    style: HomeDesign.text(15, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
