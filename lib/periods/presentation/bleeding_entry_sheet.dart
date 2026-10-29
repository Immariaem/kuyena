import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';
import '../../journal/application/day_journal.dart';
import '../../journal/domain/day_entry.dart';
import '../domain/calendar_date.dart';

/// A separate correction route for bleeding saved before the quick actions.
Future<bool?> showBleedingEntry(
  BuildContext context,
  DayJournal journal,
  CalendarDate date,
) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: Colors.white,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _BleedingEntry(journal: journal, date: date),
);

class _BleedingEntry extends StatefulWidget {
  const _BleedingEntry({required this.journal, required this.date});
  final DayJournal journal;
  final CalendarDate date;
  @override
  State<_BleedingEntry> createState() => _BleedingEntryState();
}

class _BleedingEntryState extends State<_BleedingEntry> {
  FlowIntensity? _flow;
  bool _loading = true, _failed = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await widget.journal.load();
      if (mounted) setState(() => _flow = data.entryFor(widget.date)?.flow);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.journal.setFlow(widget.date, _flow);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Nicht gespeichert. Bitte versuche es erneut.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(FlowIntensity? flow) => switch (flow) {
    null => 'Keine Angabe',
    FlowIntensity.none => 'Keine Blutung',
    FlowIntensity.light => 'Leicht',
    FlowIntensity.medium => 'Mittel',
    FlowIntensity.heavy => 'Stark',
  };
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Blutungsangabe', style: HomeDesign.text(26)),
            Text(widget.date.display, style: HomeDesign.text(16)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_failed) ...[
              Text(
                'Die Angabe konnte nicht geladen werden.',
                style: HomeDesign.text(14),
              ),
              TextButton(
                onPressed: _load,
                child: const Text('Erneut versuchen'),
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final flow in <FlowIntensity?>[
                    null,
                    ...FlowIntensity.values,
                  ])
                    ChoiceChip(
                      key: ValueKey('bleeding-${flow?.name ?? 'unset'}'),
                      label: Text(_label(flow), style: HomeDesign.text(14)),
                      selected: _flow == flow,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _flow = flow),
                      selectedColor: HomeDesign.pink,
                      backgroundColor: HomeDesign.palePink,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '„Keine Blutung“ beendet die laufende Periode mit dem Vortag als letztem Blutungstag. „Keine Angabe“ entfernt nur diese Blutungsangabe. Symptome und Wohlbefinden bleiben erhalten.',
                style: HomeDesign.text(
                  13,
                  color: HomeDesign.muted,
                  weight: FontWeight.w600,
                ),
              ),
              if (_error != null) Text(_error!, style: HomeDesign.text(14)),
              const SizedBox(height: 16),
              DesignButton(
                key: const ValueKey('save-bleeding'),
                label: _saving ? 'Wird gespeichert…' : 'Speichern',
                onPressed: _saving ? null : _save,
              ),
            ],
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text('Abbrechen', style: HomeDesign.text(14)),
            ),
          ],
        ),
      ),
    ),
  );
}
