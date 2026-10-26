import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/period_diary.dart';
import '../domain/period.dart';
import 'period_entry_dialog.dart';

class PeriodHomePage extends StatefulWidget {
  const PeriodHomePage({
    super.key,
    required this.diary,
    this.openEntryOnLoad = false,
  });
  final PeriodDiary diary;
  final bool openEntryOnLoad;

  @override
  State<PeriodHomePage> createState() => _PeriodHomePageState();
}

class _PeriodHomePageState extends State<PeriodHomePage> {
  List<Period> _periods = const [];
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  String? _error;

  bool get _busy => _loading || _saving;

  @override
  void initState() {
    super.initState();
    _loadInitialEntries();
  }

  Future<void> _loadInitialEntries() async {
    await _load();
    if (mounted && !_loadFailed && widget.openEntryOnLoad) {
      await _editPeriod();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final periods = await widget.diary.load();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _error =
            'Deine Einträge konnten nicht geladen werden. '
            'Versuche es erneut. Vorhandene Daten werden nicht überschrieben.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _perform(
    Future<List<Period>> Function() operation,
    String success,
  ) async {
    if (_busy) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final periods = await operation();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _loadFailed = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } on PeriodRuleException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Die Änderung konnte nicht bestätigt werden. '
              'Lade den Verlauf neu und versuche es erneut.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editPeriod([Period? previous]) async {
    if (_busy || _loadFailed) return;
    final periods = await showDialog<List<Period>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PeriodEntryDialog(
        today: widget.diary.today,
        initial: previous,
        onSave: (start, end) => previous == null
            ? widget.diary.add(start, end: end)
            : widget.diary.correct(previous.id, start, end: end),
      ),
    );
    if (periods == null || !mounted) return;
    setState(() => _periods = periods);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          previous == null ? 'Periode gespeichert.' : 'Periode korrigiert.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete([Period? period]) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          period == null ? 'Alle Einträge löschen?' : 'Eintrag löschen?',
        ),
        content: Text(
          period == null
              ? 'Alle Periodeneinträge in dieser App auf diesem Gerät bzw. in diesem Browser werden gelöscht.'
              : 'Die Periode mit Beginn am ${period.start.display} löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(
      () => period == null
          ? widget.diary.clear()
          : widget.diary.remove(period.id),
      period == null
          ? 'Alle Periodeneinträge gelöscht.'
          : 'Periodeneintrag gelöscht.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Text('Kuyena'),
        backgroundColor: const Color(0xFFFFE4EC),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.favorite_outline,
                    size: 44,
                    color: Color(0xFF9A405E),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dein Zyklus. Dein Überblick.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dokumentiere Beginn und, wenn bekannt, Ende deiner Periode. '
                    'Du kannst das Ende später ergänzen und Einträge korrigieren.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lokal aufbewahrt',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Deine Einträge bleiben auf diesem Gerät bzw. in diesem Browser. '
                            'Es gibt noch keine Synchronisation oder Sicherungskopie.',
                          ),
                          if (kIsWeb) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Browser-Prototyp: Bitte zunächst Testdaten verwenden. '
                              'Das Löschen von Website-Daten entfernt auch deine Einträge.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_busy) ...[
                    LinearProgressIndicator(
                      semanticsLabel: _loading
                          ? 'Einträge werden geladen'
                          : 'Änderung wird gespeichert',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _busy || _loadFailed
                        ? null
                        : () => _editPeriod(),
                    icon: const Icon(Icons.add),
                    label: const Text('Periode eintragen'),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Deine Perioden',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (!_loading && !_loadFailed && _periods.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Noch keine Einträge. Wann hat deine letzte Periode begonnen?',
                      ),
                    ),
                  for (final period in _periods)
                    Card(
                      key: ValueKey(period.id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Periodenbeginn: ${period.start.display}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              period.end == null
                                  ? 'Periodenende: unbekannt'
                                  : 'Periodenende: ${period.end!.display}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: _busy || _loadFailed
                                      ? null
                                      : () => _editPeriod(period),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Korrigieren'),
                                ),
                                TextButton.icon(
                                  onPressed: _busy || _loadFailed
                                      ? null
                                      : () => _confirmDelete(period),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Löschen'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _busy ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Verlauf neu laden'),
                      ),
                      if (_periods.isNotEmpty || _loadFailed)
                        TextButton.icon(
                          onPressed: _busy ? null : () => _confirmDelete(),
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('Alle Einträge löschen'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
