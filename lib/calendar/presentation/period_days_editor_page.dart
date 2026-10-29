import 'package:flutter/material.dart';
import '../../home/presentation/home_design.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../periods/application/period_day_editor.dart';
import '../../periods/application/period_diary.dart';
import '../../periods/domain/calendar_date.dart';
import 'calendar_widgets.dart';

class PeriodDaysEditorPage extends StatefulWidget {
  const PeriodDaysEditorPage({
    super.key,
    required this.editor,
    required this.initialDate,
  });
  final PeriodDayEditor editor;
  final CalendarDate initialDate;
  @override
  State<PeriodDaysEditorPage> createState() => _PeriodDaysEditorPageState();
}

class _PeriodDaysEditorPageState extends State<PeriodDaysEditorPage> {
  late DateTime _month;
  PeriodDaySnapshot? _snapshot;
  final _changes = <CalendarDate, bool>{};
  bool _loading = true, _saving = false, _failed = false;
  String? _error;
  Map<CalendarDate, bool>? _rangeBefore;
  CalendarDate? _rangeStart;
  bool _rangeValue = true;
  @override
  void initState() {
    super.initState();
    _month = DateTime(
      widget.initialDate.value.year,
      widget.initialDate.value.month,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _error = null;
    });
    try {
      final data = await widget.editor.load();
      if (mounted) {
        setState(() {
          _snapshot = data;
          _changes.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _error = 'Deine Periodentage konnten nicht geladen werden.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _selected(CalendarDate date) =>
      _changes[date] ?? _snapshot?.contains(date) ?? false;
  void _toggle(CalendarDate date) {
    if (_saving || _snapshot == null || date.compareTo(_snapshot!.today) > 0) {
      return;
    }
    setState(() {
      final next = !_selected(date);
      if (next == _snapshot!.contains(date)) {
        _changes.remove(date);
      } else {
        _changes[date] = next;
      }
      _error = null;
    });
  }

  void _beginRange(CalendarDate date) {
    if (_saving || _snapshot == null || date.compareTo(_snapshot!.today) > 0) {
      return;
    }
    _rangeBefore = Map.of(_changes);
    _rangeStart = date;
    _rangeValue = !_selected(date);
    _updateRange(date);
  }

  void _updateRange(CalendarDate date) {
    final start = _rangeStart, before = _rangeBefore, snapshot = _snapshot;
    if (_saving || start == null || before == null || snapshot == null) return;
    final end = date.compareTo(snapshot.today) > 0 ? snapshot.today : date;
    final first = start.compareTo(end) <= 0 ? start : end;
    final last = start.compareTo(end) <= 0 ? end : start;
    setState(() {
      // Rebuild from the draft at pointer-down: backtracking contracts the
      // current range while preserving earlier edits and repeated crossings.
      _changes
        ..clear()
        ..addAll(before);
      for (var d = first; ; d = d.addDays(1)) {
        if (_rangeValue == snapshot.contains(d)) {
          _changes.remove(d);
        } else {
          _changes[d] = _rangeValue;
        }
        if (d == last) break;
      }
      _error = null;
    });
  }

  void _finishRange() => setState(() {
    _rangeBefore = null;
    _rangeStart = null;
  });
  void _cancelRange() {
    final before = _rangeBefore;
    if (before == null) return;
    setState(() {
      _changes
        ..clear()
        ..addAll(before);
      _rangeBefore = null;
      _rangeStart = null;
    });
  }

  Future<bool> _mayLeave() async {
    if (_saving) return false;
    if (_changes.isEmpty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Änderungen verwerfen?'),
            content: const Text(
              'Deine geänderten Periodentage sind noch nicht gespeichert.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Weiter bearbeiten'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Verwerfen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _close() async {
    _cancelRange();
    if (await _mayLeave() && mounted) {
      setState(() => _changes.clear());
      Navigator.pop(context);
    }
  }

  Future<void> _reload() async {
    if (await _mayLeave() && mounted) await _load();
  }

  Future<void> _save() async {
    if (_saving ||
        _changes.isEmpty ||
        _snapshot == null ||
        _rangeBefore != null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.editor.save(_snapshot!, Map.of(_changes));
      if (mounted) {
        setState(() => _changes.clear());
        Navigator.pop(context, true);
      }
    } on PeriodRuleException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Speichern konnte nicht bestätigt werden. Deine Auswahl bleibt hier.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && _changes.isEmpty,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop) await _close();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFFFF7F9),
      appBar: AppBar(
        backgroundColor: HomeDesign.red,
        foregroundColor: Colors.white,
        title: Text(
          'Periodentage',
          style: HomeDesign.text(23, color: Colors.white),
        ),
        leading: IconButton(
          tooltip: 'Bearbeitung schließen',
          onPressed: _saving ? null : _close,
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Einzelne Tage antippen oder kurz gedrückt halten und über mehrere Tage ziehen. Start auf einem markierten Tag entfernt den Bereich. Erst Speichern übernimmt deine Auswahl.',
                    style: HomeDesign.text(14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  MonthArrows(
                    month: _month,
                    onChanged: (month) {
                      if (!_saving && _rangeBefore == null) {
                        setState(() => _month = month);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _failed
                        ? Center(
                            child: Text(_error!, style: HomeDesign.text(16)),
                          )
                        : SingleChildScrollView(
                            child: MonthCard(
                              month: _month,
                              today: _snapshot!.today,
                              onSelect: _toggle,
                              periodEditing: true,
                              onRangeStart: _saving ? null : _beginRange,
                              onRangeUpdate: _updateRange,
                              onRangeEnd: _finishRange,
                              onRangeCancel: _cancelRange,
                              periodDays: {
                                for (
                                  var d = 1;
                                  d <=
                                      DateTime(
                                        _month.year,
                                        _month.month + 1,
                                        0,
                                      ).day;
                                  d++
                                )
                                  if (_selected(
                                    CalendarDate(_month.year, _month.month, d),
                                  ))
                                    CalendarDate(_month.year, _month.month, d),
                              },
                            ),
                          ),
                  ),
                  if (_error != null && !_failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: HomeDesign.text(13)),
                    ),
                  if (_error != null)
                    TextButton(
                      onPressed: _saving ? null : _reload,
                      child: Text('Neu laden', style: HomeDesign.text(14)),
                    ),
                  const SizedBox(height: 8),
                  DesignButton(
                    key: const ValueKey('save-period-days'),
                    label: _saving ? 'Wird gespeichert…' : 'Speichern',
                    onPressed:
                        _saving ||
                            _loading ||
                            _failed ||
                            _changes.isEmpty ||
                            _rangeBefore != null
                        ? null
                        : _save,
                  ),
                  TextButton(
                    onPressed: _saving ? null : _close,
                    child: Text(
                      'Abbrechen',
                      style: HomeDesign.text(14, color: HomeDesign.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
