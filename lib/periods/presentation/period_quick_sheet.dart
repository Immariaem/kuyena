import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';
import '../../journal/application/day_journal.dart';
import '../application/period_diary.dart';
import '../application/period_quick_actions.dart';
import '../domain/calendar_date.dart';
import '../domain/period.dart';
import '../domain/period_day_overview.dart';

enum PeriodQuickResult { saved, calendar }

Future<PeriodQuickResult?> showPeriodQuickEntry(
  BuildContext context, {
  required PeriodDiary diary,
  required CalendarDate date,
  DayJournal? journal,
}) => showModalBottomSheet<PeriodQuickResult>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  useSafeArea: true,
  backgroundColor: Colors.white,
  constraints: const BoxConstraints(maxWidth: 560),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
  ),
  builder: (_) => _PeriodQuickSheet(
    actions: PeriodQuickActions(diary: diary, journal: journal),
    date: date,
  ),
);

class _PeriodQuickSheet extends StatefulWidget {
  const _PeriodQuickSheet({required this.actions, required this.date});
  final PeriodQuickActions actions;
  final CalendarDate date;
  @override
  State<_PeriodQuickSheet> createState() => _PeriodQuickSheetState();
}

class _PeriodQuickSheetState extends State<_PeriodQuickSheet> {
  late CalendarDate _date;
  Period? _target;
  bool _loading = true, _failed = false, _saving = false, _review = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _date = widget.date;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _error = null;
    });
    try {
      final day = await widget.actions.overview(_date);
      if (!mounted) return;
      setState(() {
        _target = day.period?.end == null ? day.period : null;
        _review =
            day.kind == PeriodDayKind.overlapping ||
            day.isPeriod && day.period?.end != null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date.value,
      firstDate: _target?.start.value ?? DateTime(1),
      lastDate: widget.actions.diary.today.value,
      helpText: _target == null ? 'Periodenbeginn' : 'Letzter Blutungstag',
    );
    if (date != null && mounted) {
      setState(() {
        _date = CalendarDate.fromDateTime(date);
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final target = _target;
      if (target == null) {
        await widget.actions.start(_date);
      } else {
        await widget.actions.finish(target, _date);
      }
      if (mounted) Navigator.pop(context, PeriodQuickResult.saved);
    } on PeriodRuleException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Speichern konnte nicht bestätigt werden. Deine Eingabe bleibt hier. Bitte versuche es erneut.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _review
                  ? 'Deine Periode'
                  : _target == null
                  ? 'Periode starten'
                  : 'Periode beenden',
              style: HomeDesign.text(26),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_failed) ...[
              Text(
                'Deine Periodenangaben konnten nicht geladen werden.',
                style: HomeDesign.text(15),
              ),
              TextButton(
                onPressed: _load,
                child: const Text('Erneut versuchen'),
              ),
            ] else if (_review)
              Text(
                'Für diesen Tag liegt bereits eine abgeschlossene Periode vor oder Angaben überschneiden sich. Im Verlauf kannst du die Daten prüfen und korrigieren.',
                style: HomeDesign.text(15, weight: FontWeight.w600),
              )
            else ...[
              if (_target != null) ...[
                Text(
                  'Beginn: ${_target!.start.display}',
                  style: HomeDesign.text(14, color: HomeDesign.muted),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                _target == null
                    ? 'An welchem Tag hat deine Periode begonnen?'
                    : 'Welcher war dein letzter Blutungstag?',
                style: HomeDesign.text(16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('quick-period-date'),
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 20),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeDesign.red,
                  backgroundColor: HomeDesign.palePink,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                label: Text(
                  _date == widget.actions.diary.today
                      ? 'Heute · ${_date.display}'
                      : _date.display,
                  style: HomeDesign.text(16),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _target == null
                    ? 'Der Beginn zählt als Tag 1. Die Periode bleibt aktiv, bis du sie beendest.'
                    : 'Dieser Tag zählt noch zur Periode. Ab dem folgenden Tag gilt sie als beendet.',
                style: HomeDesign.text(
                  13,
                  color: HomeDesign.muted,
                  weight: FontWeight.w600,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: HomeDesign.text(14)),
                ),
              const SizedBox(height: 20),
              DesignButton(
                key: const ValueKey('save-quick-period'),
                label: _saving ? 'Wird gespeichert…' : 'Speichern',
                onPressed: _saving ? null : _save,
              ),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.pop(context, PeriodQuickResult.calendar),
              child: Text('Periodenverlauf öffnen', style: HomeDesign.text(14)),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(
                'Abbrechen',
                style: HomeDesign.text(14, color: HomeDesign.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
