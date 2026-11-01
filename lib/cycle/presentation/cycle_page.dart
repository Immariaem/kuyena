import '../../periods/presentation/period_home_page.dart';
import '../../periods/domain/cycle_estimate.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/presentation/onboarding_flow.dart';
import '../../profile/presentation/privacy_page.dart';
import '../../data/application/data_backup_service.dart';
import '../../data/backup/backup_files.dart';
import '../../data/presentation/data_backup_page.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';
import '../../journal/application/day_journal.dart';
import '../../journal/domain/day_entry.dart';
import '../../periods/application/period_diary.dart';
import '../../periods/application/period_timeline.dart';
import '../../periods/domain/period.dart';

class CyclePage extends StatefulWidget {
  const CyclePage({
    super.key,
    required this.diary,
    required this.journal,
    required this.onSelect,
    required this.onLog,
    required this.onHistory,
    this.backupService,
    this.backupFiles,
    this.profileController,
  });
  final DataBackupService? backupService;
  final BackupFiles? backupFiles;
  final ProfileController? profileController;
  final PeriodDiary diary;
  final DayJournal journal;
  final ValueChanged<int> onSelect;
  final VoidCallback onLog, onHistory;
  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> with WidgetsBindingObserver {
  List<Period> _periods = [];
  JournalData _journal = JournalData();
  bool _loading = true, _failed = false, _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await widget.profileController?.load();
      final data = await Future.wait<Object>([
        widget.diary.load(),
        widget.journal.load(),
      ]);
      if (mounted) {
        setState(() {
          _journal = data[1] as JournalData;
          _periods = PeriodTimeline.from(
            periods: data[0] as List<Period>,
            entries: _journal.entries,
            periodDays: _journal.periodDays,
            asOf: widget.diary.today,
          ).periods;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<int> get _intervals {
    final sorted = _periods.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return [
      for (var i = 1; i < sorted.length; i++)
        if ((sorted[i - 1].end == null ||
                sorted[i - 1].end!.compareTo(sorted[i].start) < 0) &&
            !sorted[i - 1].isOngoing)
          sorted[i - 1].start.daysUntil(sorted[i].start),
    ];
  }

  CycleEstimate? get _estimate => CycleEstimate.fromPeriods(
    _periods,
    initialLength: widget.profileController?.value?.exactCycleDays,
  );

  String _average(List<int> values) => values.isEmpty
      ? '—'
      : '${(values.reduce((a, b) => a + b) / values.length).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')} d';
  Future<void> _preferences([int? section]) async {
    if (_busy || widget.profileController == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OnboardingFlow(
          controller: widget.profileController!,
          editing: true,
          initialSection: section,
          onEditPeriods: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PeriodHomePage(
                  diary: widget.diary,
                  journal: widget.journal,
                ),
              ),
            );
            await widget.profileController!.load();
          },
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _reminders() async {
    if (widget.profileController != null) {
      await _preferences(7);
      return;
    }

    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.journal.setReminders(!_journal.reminders);
      await _load();
      if (mounted) setState(() => _busy = false);
      if (mounted && _journal.reminders) {
        await showDesignInfo(
          context,
          'Reminders',
          'Kuyena will show a reminder on Home if you have not logged today. This works while the app is open. Phone notifications and background reminders are not connected yet.',
        );
      }
    } catch (_) {
      if (mounted) {
        await showDesignInfo(
          context,
          'Could not save',
          'Your reminder setting could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backup() async {
    if (_busy || widget.backupService == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DataBackupPage(
          service: widget.backupService!,
          files: widget.backupFiles ?? BackupFiles(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Read both sources again before exporting; never export a partial load.
      final data = await Future.wait<Object>([
        widget.diary.load(),
        widget.journal.load(),
      ]);
      final periods = data[0] as List<Period>, journal = data[1] as JournalData;
      final json = widget.backupService != null
          ? await widget.backupService!.jsonExport()
          : const JsonEncoder.withIndent('  ').convert({
              'format': 'kuyena-export',
              'version': 2,
              'periods': periods
                  .map(
                    (p) => {
                      'id': p.id,
                      'start': p.start.iso,
                      'end': p.end?.iso,
                      'ongoing': p.isOngoing,
                    },
                  )
                  .toList(),
              'dayEntries': journal.entries.map((e) => e.toJson()).toList(),
              'periodDays': [
                for (final date in journal.periodDays.keys.toList()..sort())
                  {'date': date.iso, 'period': journal.periodDays[date]},
              ],
              'reminders': journal.reminders,
            });
      if (!mounted) return;
      setState(() => _busy = false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) => FractionallySizedBox(
          heightFactor: .8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Export data', style: HomeDesign.text(26)),
                const SizedBox(height: 8),
                Text(
                  'Copy your JSON export and save it as a text file. It contains your sensitive entries in readable form.',
                  style: HomeDesign.text(
                    14,
                    color: HomeDesign.muted,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      json,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DesignButton(
                  label: 'Copy JSON export',
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: json));
                      if (context.mounted && mounted) {
                        Navigator.pop(context);
                        showDesignNotice(this.context, 'Export copied.');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        await showDesignInfo(
                          context,
                          'Copy unavailable',
                          'Select the export text and copy it manually. Your stored entries have not been changed.',
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        await showDesignInfo(
          context,
          'Export unavailable',
          'Could not read all your data. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'This permanently removes your period dates, day entries, personal preferences and reminder settings from this app on this device. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (widget.backupService != null) {
        await widget.backupService!.store.clear();
      } else {
        await widget.diary.clear();
        await widget.journal.clear();
      }
      await _load();
      if (mounted) {
        showDesignNotice(context, 'Local data deleted.');
      }
    } catch (_) {
      await _load();
      if (mounted) {
        await showDesignInfo(
          context,
          'Deletion incomplete',
          'Deletion could not be fully confirmed. Please reload and try again. Any old storage copies must also be removed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stat(String value, String title, {bool initial = false}) => Expanded(
    child: Container(
      height: 139,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: HomeDesign.pink,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: HomeDesign.text(28, height: 1.214)),
          const SizedBox(height: 2),
          Text(
            initial ? 'Erster Richtwert' : 'Average',
            style: HomeDesign.text(11, height: 1.273),
          ),
          const SizedBox(height: 2),
          Text(title, style: HomeDesign.text(15, height: 1.333)),
        ],
      ),
    ),
  );
  Widget _row(
    String label,
    String asset,
    VoidCallback? action, {
    String? hint,
    Widget? trailing,
    bool disabled = false,
  }) => Material(
    color: HomeDesign.palePink,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: ValueKey('cycle-$label'),
      onTap: _busy ? null : action,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            DesignAsset(asset, width: 22, height: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: HomeDesign.text(
                      16,
                      color: disabled ? HomeDesign.muted : HomeDesign.red,
                      height: 1.3,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      hint,
                      style: HomeDesign.text(
                        12,
                        color: HomeDesign.muted,
                        weight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (!disabled)
              const DesignAsset('a78ab.svg', width: 18, height: 18),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => KuyenaPage(
    title: 'Cycle & App',
    subtitle: 'Your cycle. Your pace.',
    active: 3,
    onSelect: (i) {
      if (!_busy) widget.onSelect(i);
    },
    onLog: () {
      if (!_busy) widget.onLog();
    },
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? Column(
            children: [
              Text(
                'Could not load your data. Existing entries have not been changed.',
                style: HomeDesign.text(16),
              ),
              const SizedBox(height: 16),
              DesignButton(label: 'Try again', onPressed: _load),
              if (widget.backupService != null) ...[
                const SizedBox(height: 12),
                DesignButton(
                  label: 'Sicherung wiederherstellen',
                  onPressed: _busy ? null : _backup,
                ),
                TextButton(
                  onPressed: _busy ? null : _clear,
                  child: const Text('Alle lokalen Daten löschen'),
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _stat(
                    _intervals.isEmpty && _estimate != null
                        ? '${_estimate!.lengthInDays} d'
                        : _average(_intervals),
                    'Cycle length',
                    initial: _intervals.isEmpty && _estimate?.isInitial == true,
                  ),
                  const SizedBox(width: 14),
                  _stat(
                    _average([
                      for (final p in _periods)
                        if (p.end != null) p.documentedDayCount!,
                    ]),
                    'Period length',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _periods.isEmpty
                    ? 'Averages will appear after you log your periods.'
                    : 'Based on recorded dates. Tap for calculation details.',
                style: HomeDesign.text(
                  12,
                  weight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (_periods.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => showDesignInfo(
                      context,
                      'Your averages',
                      'Cycle length is the arithmetic mean of ${_intervals.length} recorded start-to-start intervals. An interval is skipped if the earlier period is still marked ongoing or its end overlaps the next start. Period length counts marked bleeding days in completed periods; removed calendar days are excluded. The Home countdown uses the rounded arithmetic mean of the recorded start intervals. Before an interval is available, your precise self-reported length or a provisional general 28-day reference is used. More observations personalize the mean without guaranteeing accuracy. These summaries are not a diagnosis.',
                    ),
                    child: Text(
                      'Calculation details',
                      style: HomeDesign.text(12),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Material(
                color: HomeDesign.palePink,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: widget.onHistory,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent periods',
                          style: HomeDesign.text(20, height: 1.25),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _periods.isEmpty
                              ? 'No periods logged yet.'
                              : _periods
                                    .take(2)
                                    .map(
                                      (p) =>
                                          '${p.start.display}  –  ${p.isOngoing ? 'ongoing' : p.end?.display ?? 'end unknown'}',
                                    )
                                    .join('\n'),
                          style: HomeDesign.text(
                            13,
                            weight: FontWeight.w600,
                            height: 1.385,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _periods.isEmpty
                              ? 'Log your first entry →'
                              : 'View and edit periods →',
                          style: HomeDesign.text(15, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (widget.profileController != null) ...[
                _row(
                  'Deine Angaben & Einstellungen',
                  '2acf8.svg',
                  _preferences,
                  hint: 'Zyklus, Ziele, Tracking, Bewegung, Ernährung',
                ),
                const SizedBox(height: 4),
              ],
              _row('Edit cycle data', '2acf8.svg', widget.onHistory),
              const SizedBox(height: 4),
              _row(
                'Reminders',
                '4d5fb.svg',
                _reminders,
                hint: widget.profileController == null
                    ? null
                    : 'Uhrzeit und Hinweise innerhalb der App',
                trailing: Semantics(
                  toggled: _journal.reminders,
                  button: true,
                  label: 'In-app reminders',
                  child: _journal.reminders
                      ? Container(
                          width: 44,
                          height: 27,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: HomeDesign.red,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 21,
                            height: 21,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const DesignAsset('e24ba.svg', width: 44, height: 27),
                ),
              ),
              const SizedBox(height: 4),
              _row(
                'Export data',
                '8635b.svg',
                _periods.isEmpty &&
                        _journal.entries.isEmpty &&
                        _journal.periodDays.isEmpty
                    ? null
                    : _export,
                disabled:
                    _periods.isEmpty &&
                    _journal.entries.isEmpty &&
                    _journal.periodDays.isEmpty,
                hint:
                    _periods.isEmpty &&
                        _journal.entries.isEmpty &&
                        _journal.periodDays.isEmpty
                    ? 'Available after your first entry.'
                    : null,
              ),
              const SizedBox(height: 4),
              if (widget.backupService != null) ...[
                _row('Sicherung & Wiederherstellung', '8635b.svg', _backup),
                const SizedBox(height: 4),
              ],
              _row('Delete all local data', 'f680b.svg', _clear),
              const SizedBox(height: 4),
              _row(
                'Privacy information',
                '50cd2.svg',
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
                ),
              ),
              const SizedBox(height: 4),
              _row(
                'About the app',
                '04493.svg',
                () => showDesignInfo(
                  context,
                  'About Kuyena',
                  'Kuyena is a free, open-source cycle journal in development. You can record period dates and daily observations, and view your own history.\n\nPredictions are approximate. General food and movement ideas are not personal medical recommendations. Reminder notices currently appear inside the app only.',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DesignAsset('87364.svg', width: 18, height: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No account needed. Your data stays on this device.',
                      style: HomeDesign.text(
                        12.5,
                        weight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(color: HomeDesign.red),
                ),
            ],
          ),
  );
}
