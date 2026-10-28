import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';
import '../../periods/domain/calendar_date.dart';
import '../application/day_journal.dart';
import '../domain/day_entry.dart';

String symptomLabel(Symptom s) => switch (s) {
  Symptom.cramps => 'Cramps',
  Symptom.headache => 'Headache',
  Symptom.fatigue => 'Fatigue',
  Symptom.breastTenderness => 'Breast tenderness',
};
String flowLabel(FlowIntensity f) => switch (f) {
  FlowIntensity.none => 'None',
  FlowIntensity.light => 'Light',
  FlowIntensity.medium => 'Medium',
  FlowIntensity.heavy => 'Heavy',
};
String moodLabel(Mood m) => switch (m) {
  Mood.good => 'Good',
  Mood.okay => 'Okay',
  Mood.low => 'Low',
};

class DayEntryPage extends StatefulWidget {
  const DayEntryPage({
    super.key,
    required this.date,
    required this.journal,
    required this.onSaved,
    required this.onBack,
    required this.onSelectTab,
    required this.active,
  });
  final CalendarDate date;
  final DayJournal journal;
  final VoidCallback onSaved, onBack;
  final ValueChanged<int> onSelectTab;
  final int active;
  @override
  State<DayEntryPage> createState() => _DayEntryPageState();
}

class _DayEntryPageState extends State<DayEntryPage> {
  FlowIntensity? _flow;
  final _symptoms = <Symptom>{};
  Mood? _mood;
  int? _energy;
  final _note = TextEditingController();
  final _energyFocus = FocusNode();
  bool _loading = true,
      _failed = false,
      _saving = false,
      _existing = false,
      _dirty = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _energyFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await widget.journal.load();
      if (!mounted) return;
      final entry = data.entryFor(widget.date);
      setState(() {
        _existing = entry != null;
        _flow = entry?.flow;
        _symptoms.addAll(entry?.symptoms ?? {});
        _mood = entry?.mood;
        _energy = entry?.energy;
        _note.text = entry?.note ?? '';
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _leave() async {
    if (_saving) return false;
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Your changes have not been saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _navigate(VoidCallback action) async {
    if (await _leave() && mounted) action();
  }

  Future<void> _save() async {
    final entry = DayEntry(
      date: widget.date,
      flow: _flow,
      symptoms: _symptoms,
      mood: _mood,
      energy: _energy,
      note: _note.text.trim(),
    );
    if (entry.isEmpty) {
      setState(() => _error = 'Choose at least one observation or add a note.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.journal.save(entry);
      if (mounted) {
        _dirty = false;
        widget.onSaved();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save. Your draft is still here. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this day entry?'),
        content: const Text(
          'This removes the symptoms, mood, energy and note for this day. Period dates stay as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.journal.remove(widget.date);
      if (mounted) {
        _dirty = false;
        widget.onSaved();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not delete. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _header(String title, [String? hint]) => Row(
    children: [
      Text(title, style: HomeDesign.text(16, height: 1.3)),
      const SizedBox(width: 8),
      if (hint != null)
        Expanded(
          child: Text(
            hint,
            textAlign: TextAlign.end,
            style: HomeDesign.text(
              12,
              color: HomeDesign.muted,
              weight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
    ],
  );
  Widget _chip(String id, String label, bool selected, VoidCallback change) =>
      Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? HomeDesign.red : HomeDesign.palePink,
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            key: ValueKey(id),
            onTap: _saving
                ? null
                : () => setState(() {
                    change();
                    _dirty = true;
                  }),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${selected ? '✓ ' : ''}$label',
                  style: HomeDesign.text(
                    14,
                    color: selected ? Colors.white : HomeDesign.red,
                    weight: selected ? FontWeight.w800 : FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  Widget _row(List<Widget> chips, double gap) => Row(
    children: [
      for (var i = 0; i < chips.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: chips[i]),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop) await _navigate(widget.onBack);
    },
    child: KuyenaPage(
      title: 'Log your day',
      subtitle:
          'Add your symptoms, mood\nand energy for ${fullDate(widget.date)}.',
      compactHeader: true,
      active: widget.active,
      onSelect: (i) => _navigate(() => widget.onSelectTab(i)),
      onLog: () => _navigate(widget.onBack),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      trailing: TextButton(
        onPressed: _saving ? null : () => _navigate(widget.onBack),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DesignAsset('54065.svg', width: 32, height: 32),
            const SizedBox(width: 8),
            Text(
              'Back to date',
              style: HomeDesign.text(14, color: Colors.white),
            ),
          ],
        ),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? Column(
              children: [
                Text(
                  'Could not load this day. Existing data has not been changed.',
                  style: HomeDesign.text(16),
                ),
                DesignButton(label: 'Try again', onPressed: _load),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DateSummary(date: widget.date, today: widget.journal.today),
                const SizedBox(height: 12),
                _header(
                  'Flow',
                  _dirty
                      ? 'Draft'
                      : _existing
                      ? 'Saved'
                      : 'Not set',
                ),
                const SizedBox(height: 5),
                _row([
                  for (final f in FlowIntensity.values)
                    _chip(
                      'flow-${f.name}',
                      flowLabel(f),
                      _flow == f,
                      () => _flow = _flow == f ? null : f,
                    ),
                ], 6),
                const SizedBox(height: 18),
                _header('Symptoms', 'Select all that apply'),
                const SizedBox(height: 5),
                _row([
                  for (final s in Symptom.values.take(2))
                    _chip(
                      'symptom-${s.name}',
                      symptomLabel(s),
                      _symptoms.contains(s),
                      () => _symptoms.contains(s)
                          ? _symptoms.remove(s)
                          : _symptoms.add(s),
                    ),
                ], 8),
                const SizedBox(height: 5),
                _row([
                  for (final s in Symptom.values.skip(2))
                    _chip(
                      'symptom-${s.name}',
                      symptomLabel(s),
                      _symptoms.contains(s),
                      () => _symptoms.contains(s)
                          ? _symptoms.remove(s)
                          : _symptoms.add(s),
                    ),
                ], 8),
                const SizedBox(height: 18),
                _header('Mood'),
                const SizedBox(height: 5),
                _row([
                  for (final m in Mood.values)
                    _chip(
                      'mood-${m.name}',
                      moodLabel(m),
                      _mood == m,
                      () => _mood = _mood == m ? null : m,
                    ),
                ], 6),
                const SizedBox(height: 18),
                _header(
                  'Energy',
                  _energy == null
                      ? 'Not set'
                      : _energy! < 34
                      ? 'Low'
                      : _energy! < 67
                      ? 'Medium'
                      : 'High',
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      'Low',
                      style: HomeDesign.text(12, weight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => SizedBox(
                          height: 32,
                          child: Stack(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 6,
                                  activeTrackColor: HomeDesign.red,
                                  inactiveTrackColor: HomeDesign.palePink,
                                  thumbColor: Colors.transparent,
                                  overlayShape: SliderComponentShape.noOverlay,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 13,
                                  ),
                                ),
                                child: Slider(
                                  key: const ValueKey('energy-slider'),
                                  focusNode: _energyFocus,
                                  value: (_energy ?? 50) / 100,
                                  padding: EdgeInsets.zero,
                                  semanticFormatterCallback: (v) =>
                                      'Energy ${(v * 100).round()} of 100',
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() {
                                          _energy = (v * 100).round();
                                          _dirty = true;
                                        }),
                                ),
                              ),
                              Positioned(
                                left: (c.maxWidth - 26) * (_energy ?? 50) / 100,
                                top: 3,
                                child: const IgnorePointer(
                                  child: DesignAsset(
                                    '33621.svg',
                                    width: 26,
                                    height: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'High',
                      style: HomeDesign.text(12, weight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _header('Note', 'Optional'),
                const SizedBox(height: 5),
                TextField(
                  key: const ValueKey('day-note'),
                  controller: _note,
                  enabled: !_saving,
                  onChanged: (_) => setState(() => _dirty = true),
                  style: HomeDesign.text(
                    14,
                    color: HomeDesign.ink,
                    weight: FontWeight.w600,
                  ),
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    constraints: const BoxConstraints(minHeight: 44),
                    hintText: 'What would you like to note?',
                    hintStyle: HomeDesign.text(
                      14,
                      color: HomeDesign.muted,
                      weight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: HomeDesign.palePink,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: HomeDesign.text(14)),
                  ),
                const SizedBox(height: 18),
                DesignButton(
                  key: const ValueKey('save-day-entry'),
                  label: _saving ? 'Saving…' : 'Save entry',
                  onPressed: _saving ? null : _save,
                ),
                if (_existing)
                  TextButton(
                    onPressed: _saving ? null : _delete,
                    child: Text(
                      'Delete this entry',
                      style: HomeDesign.text(14),
                    ),
                  ),
              ],
            ),
    ),
  );
}
