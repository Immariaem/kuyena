import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../home/presentation/home_design.dart';
import '../../app/presentation/kuyena_components.dart';

import '../application/period_diary.dart';
import '../application/period_timeline.dart';
import '../domain/calendar_date.dart';
import '../../journal/application/day_journal.dart';
import '../../journal/domain/day_entry.dart';
import '../../journal/presentation/day_entry_labels.dart';
import '../domain/period.dart';
import 'period_entry_dialog.dart';
import 'bleeding_entry_sheet.dart';

class PeriodHomePage extends StatefulWidget {
  const PeriodHomePage({
    super.key,
    required this.diary,
    this.openEntryOnLoad = false,
    this.journal,
  });
  final PeriodDiary diary;
  final DayJournal? journal;
  final bool openEntryOnLoad;

  @override
  State<PeriodHomePage> createState() => _PeriodHomePageState();
}

class _PeriodHomePageState extends State<PeriodHomePage> {
  List<Period> _periods = const [];
  List<Period> _logPeriods = const [];
  List<DayEntry> _flowEntries = const [];
  Map<String, Period> _computed = {};
  Set<String> _logAdjusted = {};
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
      final values = await Future.wait<Object>([
        widget.diary.load(),
        widget.journal?.load() ?? Future.value(JournalData()),
      ]);
      final periods = values[0] as List<Period>;
      final timeline = PeriodTimeline.from(
        periods: periods,
        entries: (values[1] as JournalData).entries,
        asOf: widget.diary.today,
      );
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _flowEntries = (values[1] as JournalData).entries
            .where((e) => e.flow != null)
            .toList();
        _logPeriods = timeline.periods
            .where((p) => timeline.logPeriodIds.contains(p.id))
            .toList();
        _computed = {for (final p in timeline.periods) p.id: p};
        _logAdjusted = timeline.logAdjustedIds;
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
      await _load();
      if (!mounted || _loadFailed) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
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
        onSave: (start, end, isOngoing) => previous == null
            ? widget.diary.add(start, end: end, isOngoing: isOngoing)
            : widget.diary.correct(
                previous.id,
                start,
                end: end,
                isOngoing: isOngoing,
              ),
      ),
    );
    if (periods == null || !mounted) return;
    setState(() => _periods = periods);
    await _load();
    if (!mounted || _loadFailed) return;
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
        title: Text(
          period == null ? 'Alle Einträge löschen?' : 'Eintrag löschen?',
        ),
        content: Text(
          period == null
              ? 'Alle manuell angelegten Periodeneinträge auf diesem Gerät bzw. in diesem Browser werden gelöscht. Deine Log-Einträge bleiben erhalten.'
              : 'Die Periode mit Beginn am ${period.start.display} löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Abbrechen', style: HomeDesign.text(14)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeDesign.red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
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

  Future<void> _editBleeding(CalendarDate date) async {
    final journal = widget.journal;
    if (journal == null || _busy) return;
    final saved = await showBleedingEntry(context, journal, date);
    if (saved == true && mounted) await _load();
  }

  Widget _periodCard(Period period) => Container(
    key: ValueKey(period.id),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: HomeDesign.palePink,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const DesignAsset('6ad9e.svg', width: 22, height: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Periodenbeginn: ${period.start.display}',
                style: HomeDesign.text(16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          (_computed[period.id] ?? period).isOngoing
              ? 'Periode läuft noch'
              : (_computed[period.id] ?? period).end == null
              ? 'Periodenende: unbekannt'
              : 'Periodenende: ${(_computed[period.id] ?? period).end!.display}',
          style: HomeDesign.text(
            14,
            color: HomeDesign.muted,
            weight: FontWeight.w600,
          ),
        ),
        if (_logAdjusted.contains(period.id)) ...[
          const SizedBox(height: 8),
          Text(
            'Mit deinen Blutungsangaben aus dem Log ergänzt.',
            style: HomeDesign.text(
              12,
              color: HomeDesign.muted,
              weight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _busy || _loadFailed
                  ? null
                  : () => _editPeriod(period),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: HomeDesign.red,
                shape: const StadiumBorder(),
              ),
              icon: const DesignAsset('2acf8.svg', width: 22, height: 22),
              label: Text('Korrigieren', style: HomeDesign.text(14)),
            ),
            TextButton.icon(
              onPressed: _busy || _loadFailed
                  ? null
                  : () => _confirmDelete(period),
              style: TextButton.styleFrom(foregroundColor: HomeDesign.red),
              icon: const DesignAsset('f680b.svg', width: 22, height: 22),
              label: Text('Löschen', style: HomeDesign.text(14)),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: HomeDesign.red),
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'NunitoSans'),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFFFF7F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width >= 900 ? 24 : 0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kIsWeb ? 30 : 0),
                child: ColoredBox(
                  color: HomeDesign.red,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Zurück',
                                  onPressed: () => Navigator.maybePop(context),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Deine Perioden',
                                      style: HomeDesign.text(
                                        32,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 12, top: 6),
                              child: Text(
                                'Beginn und Ende an einem Ort.',
                                style: HomeDesign.text(
                                  15,
                                  color: Colors.white,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Dein Zyklus. Dein Überblick.',
                                  style: HomeDesign.text(22),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Trage den ersten und, wenn bekannt, den letzten Periodentag ein. Du kannst deine Angaben später anpassen.',
                                  style: HomeDesign.text(
                                    14,
                                    color: HomeDesign.muted,
                                    weight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (_busy) ...[
                                  LinearProgressIndicator(
                                    color: HomeDesign.red,
                                    backgroundColor: HomeDesign.palePink,
                                    semanticsLabel: _loading
                                        ? 'Einträge werden geladen'
                                        : 'Änderung wird gespeichert',
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: HomeDesign.palePink,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        _error!,
                                        style: HomeDesign.text(14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (!_loading &&
                                    !_loadFailed &&
                                    _periods.isEmpty &&
                                    _logPeriods.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: HomeDesign.palePink,
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const DesignAsset(
                                          '6ad9e.svg',
                                          width: 22,
                                          height: 22,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Dein erster Eintrag',
                                          style: HomeDesign.text(20),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Noch keine Einträge. Wann hat deine letzte Periode begonnen?',
                                          style: HomeDesign.text(
                                            14,
                                            color: HomeDesign.muted,
                                            weight: FontWeight.w600,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                for (final period in _periods)
                                  _periodCard(period),
                                if (_logPeriods.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aus deinem Log',
                                    style: HomeDesign.text(20),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Diese Perioden folgen deinen gespeicherten Blutungsangaben. Du kannst diese Angaben hier getrennt vom Wohlbefinden bearbeiten.',
                                    style: HomeDesign.text(
                                      13,
                                      color: HomeDesign.muted,
                                      weight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (final period in _logPeriods)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: HomeDesign.palePink,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Periodenbeginn: ${period.start.display}',
                                            style: HomeDesign.text(16),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            period.isOngoing
                                                ? 'Periode läuft noch'
                                                : period.end == null
                                                ? 'Periodenende: unbekannt'
                                                : 'Periodenende: ${period.end!.display}',
                                            style: HomeDesign.text(
                                              14,
                                              color: HomeDesign.muted,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                          if (widget.journal != null) ...[
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      _editBleeding(
                                                        period.start,
                                                      ),
                                                  child: Text(
                                                    'Blutungsangabe bearbeiten',
                                                    style: HomeDesign.text(14),
                                                  ),
                                                ),
                                                if (period.isOngoing)
                                                  TextButton(
                                                    onPressed: () =>
                                                        _editBleeding(
                                                          widget.diary.today,
                                                        ),
                                                    child: Text(
                                                      'Blutung für heute',
                                                      style: HomeDesign.text(
                                                        14,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                ],
                                if (_flowEntries.isNotEmpty)
                                  Material(
                                    color: Colors.transparent,
                                    child: ExpansionTile(
                                      key: const ValueKey(
                                        'bleeding-observations',
                                      ),
                                      tilePadding: EdgeInsets.zero,
                                      title: Text(
                                        'Blutungsangaben prüfen',
                                        style: HomeDesign.text(16),
                                      ),
                                      children: [
                                        for (final entry in _flowEntries)
                                          ListTile(
                                            key: ValueKey(
                                              'edit-bleeding-${entry.date.iso}',
                                            ),
                                            title: Text(
                                              entry.date.display,
                                              style: HomeDesign.text(14),
                                            ),
                                            subtitle: Text(
                                              flowLabel(entry.flow!),
                                              style: HomeDesign.text(
                                                12,
                                                color: HomeDesign.muted,
                                              ),
                                            ),
                                            trailing: const Icon(
                                              Icons.edit_outlined,
                                              color: HomeDesign.red,
                                            ),
                                            onTap: _busy || _loadFailed
                                                ? null
                                                : () =>
                                                      _editBleeding(entry.date),
                                          ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _busy ? null : _load,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        color: HomeDesign.red,
                                      ),
                                      label: Text(
                                        'Verlauf neu laden',
                                        style: HomeDesign.text(14),
                                      ),
                                    ),
                                    if (_periods.isNotEmpty || _loadFailed)
                                      TextButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _confirmDelete(),
                                        icon: const DesignAsset(
                                          'f680b.svg',
                                          width: 22,
                                          height: 22,
                                        ),
                                        label: Text(
                                          'Alle Einträge löschen',
                                          style: HomeDesign.text(14),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const DesignAsset(
                                      '87364.svg',
                                      width: 18,
                                      height: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Lokal aufbewahrt. Deine Einträge bleiben auf diesem Gerät bzw. in diesem Browser.',
                                        style: HomeDesign.text(
                                          12,
                                          color: HomeDesign.muted,
                                          weight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (kIsWeb)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Browser-Prototyp: Bitte zunächst Testdaten verwenden. Das Löschen von Website-Daten entfernt auch deine Einträge.',
                                      style: HomeDesign.text(
                                        12,
                                        color: HomeDesign.muted,
                                        weight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ColoredBox(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: DesignButton(
                            label: 'Periode eintragen',
                            onPressed: _busy || _loadFailed
                                ? null
                                : () => _editPeriod(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
