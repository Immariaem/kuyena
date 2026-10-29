import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../periods/application/period_diary.dart';
import '../../periods/application/period_timeline.dart';
import '../../journal/application/day_journal.dart';
import '../../journal/domain/day_entry.dart';
import '../../journal/presentation/day_entry_labels.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../periods/domain/calendar_date.dart';
import '../../periods/domain/cycle_phase_overview.dart';
import '../../periods/domain/period.dart';
import '../../periods/domain/period_day_overview.dart';
import '../../periods/presentation/period_home_page.dart';
import '../../periods/presentation/period_quick_sheet.dart';
import 'home_design.dart';
import 'curved_date_slider.dart';
import 'cycle_phase_labels.dart';
import 'home_desktop_layout.dart';
import 'period_status_ring.dart';

/// Observations and provisional phase estimates follow the selected day.
class KuyenaHomePage extends StatefulWidget {
  const KuyenaHomePage({
    super.key,
    required this.diary,
    this.journal,
    required this.onCalendar,
    this.onLog,
    this.onForYou,
    this.onCycle,
  });

  final ValueChanged<CalendarDate> onCalendar;
  final VoidCallback? onForYou, onCycle;
  final ValueChanged<CalendarDate>? onLog;

  final PeriodDiary diary;
  final DayJournal? journal;

  @override
  State<KuyenaHomePage> createState() => _KuyenaHomePageState();
}

class _KuyenaHomePageState extends State<KuyenaHomePage>
    with WidgetsBindingObserver {
  late CalendarDate _selectedDate;
  late CalendarDate _today;
  List<Period> _periods = const [];
  JournalData _journalData = JournalData();
  PeriodTimeline? _timeline;
  bool _loadingPeriods = true;
  bool _periodLoadFailed = false;
  int _loadRequest = 0;
  Timer? _dayChangeTimer;

  @override
  void initState() {
    super.initState();
    _today = widget.diary.today;
    _selectedDate = _today;
    WidgetsBinding.instance.addObserver(this);
    _loadPeriods();
    _scheduleDayChange();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayChangeTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KuyenaHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diary != widget.diary ||
        oldWidget.journal != widget.journal) {
      _refreshDay();
      _loadPeriods();
      _scheduleDayChange();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDay();
      _loadPeriods();
      _scheduleDayChange();
    }
  }

  void _refreshDay() {
    final today = widget.diary.today;
    setState(() {
      if (_selectedDate == _today) _selectedDate = today;
      _today = today;
    });
  }

  void _scheduleDayChange() {
    _dayChangeTimer?.cancel();
    final now = widget.diary.clock();
    final nextDay = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    _dayChangeTimer = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      _refreshDay();
      _scheduleDayChange();
    });
  }

  Future<void> _loadPeriods() async {
    final request = ++_loadRequest;
    setState(() {
      _loadingPeriods = true;
      _periodLoadFailed = false;
    });
    try {
      final values = await Future.wait<Object>([
        widget.diary.load(),
        widget.journal?.load() ?? Future.value(JournalData()),
      ]);
      final journal = values[1] as JournalData;
      final timeline = PeriodTimeline.from(
        periods: values[0] as List<Period>,
        entries: journal.entries,
        asOf: _today,
      );
      if (mounted && request == _loadRequest) {
        setState(() {
          _journalData = journal;
          _timeline = timeline;
          _periods = timeline.periods;
        });
      }
    } catch (_) {
      if (mounted && request == _loadRequest) {
        setState(() => _periodLoadFailed = true);
      }
    } finally {
      if (mounted && request == _loadRequest) {
        setState(() => _loadingPeriods = false);
      }
    }
  }

  void _selectToday() {
    _refreshDay();
    setState(() => _selectedDate = _today);
    _loadPeriods();
  }

  void _selectDate(CalendarDate date) => setState(() => _selectedDate = date);

  Future<void> _openDiary({bool log = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PeriodHomePage(
          diary: widget.diary,
          openEntryOnLoad: log,
          journal: widget.journal,
        ),
      ),
    );
    if (!mounted) return;
    _refreshDay();
    await _loadPeriods();
  }

  Future<void> _quickPeriod() async {
    final result = await showPeriodQuickEntry(
      context,
      diary: widget.diary,
      journal: widget.journal,
      date: _selectedDate,
    );
    if (!mounted) return;
    if (result == PeriodQuickResult.calendar) {
      widget.onCalendar(_selectedDate);
    } else if (result == PeriodQuickResult.saved) {
      _refreshDay();
      await _loadPeriods();
    }
  }

  DayEntry? get _dayEntry => _journalData.entryFor(_selectedDate);
  PeriodDayOverview get _overview => PeriodDayOverview.fromPeriods(
    _periods,
    _selectedDate,
    asOf: _today,
    bleedingAbsent: _dayEntry?.flow == FlowIntensity.none,
    bleedingPresent:
        _dayEntry?.flow != null && _dayEntry?.flow != FlowIntensity.none,
  );

  CyclePhaseOverview get _phase => CyclePhaseOverview.fromDay(_overview);

  Widget _informationCards(double scale) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('home-period-action'),
        onPressed:
            _loadingPeriods ||
                _periodLoadFailed ||
                _selectedDate.compareTo(_today) > 0
            ? null
            : _quickPeriod,
        style: OutlinedButton.styleFrom(
          foregroundColor: HomeDesign.red,
          backgroundColor: HomeDesign.palePink,
          side: const BorderSide(color: HomeDesign.pink),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        icon: const Icon(Icons.water_drop_outlined, size: 20),
        label: Text(
          _overview.period?.end == null && _overview.period != null
              ? _overview.period!.isOngoing
                    ? 'Periode beenden'
                    : 'Ende ergänzen'
              : _overview.isPeriod
              ? 'Periode bearbeiten'
              : 'Periode starten',
          style: HomeDesign.text(15 * scale),
        ),
      ),
      SizedBox(height: 14 * scale),
      _InformationCards(
        scale: scale,
        phase: _phase,
        entry: _dayEntry,
        isToday: _selectedDate == _today,
        loading: _loadingPeriods,
        loadFailed: _periodLoadFailed,
        onPhase: _showPhaseDetails,
        onSymptoms: _showSymptomsDetails,
        onMovement:
            widget.onForYou ?? () => _showPreview(recommendations: true),
      ),
    ],
  );

  void _showPhaseDetails() {
    if (_loadingPeriods) return;
    if (_periodLoadFailed) {
      _loadPeriods();
      return;
    }
    showDesignInfo(
      context,
      phaseLabel(_phase),
      'Am ${_selectedDate.display}: ${phaseExplanation(_phase)}',
    );
  }

  void _showSymptomsDetails() {
    if (_loadingPeriods) return;
    if (_periodLoadFailed) {
      _loadPeriods();
      return;
    }
    final symptoms = _dayEntry?.symptoms ?? <Symptom>{};
    showDesignInfo(
      context,
      symptoms.isEmpty ? 'Possible symptoms' : 'Logged symptoms',
      symptoms.isEmpty
          ? 'Für den ${_selectedDate.display} sind keine Symptome eingetragen. '
                '„Cramps“ bleibt hier vorerst ein allgemeines Designbeispiel, '
                'keine Vorhersage deiner Beschwerden. Du kannst Symptome unabhängig von einer Periode im Log dokumentieren.'
          : 'Am ${_selectedDate.display} hast du folgende Symptome dokumentiert: '
                '${Symptom.values.where(symptoms.contains).map(symptomLabel).join(', ')}. '
                'Die Karte zeigt deine Einträge für den ausgewählten Tag.',
    );
  }

  Widget _periodRing(double scale) => PeriodStatusRing(
    scale: scale,
    overview: _overview,
    isToday: _selectedDate == _today,
    loading: _loadingPeriods,
    logSummary: _dayEntry == null
        ? null
        : dayEntrySummary(_dayEntry!, compact: true),
    bleedingAbsent: _dayEntry?.flow == FlowIntensity.none,
    loadFailed: _periodLoadFailed,
    onTap: () {
      if (_periodLoadFailed) {
        _loadPeriods();
      } else if (_overview.kind == PeriodDayKind.noEntry && _dayEntry == null) {
        _openDiary(log: true);
      } else {
        _showPeriodDetails();
      }
    },
  );

  Future<void> _showPeriodDetails() async {
    final overview = _overview;
    final period = overview.period;
    final entry = _dayEntry;
    if (period == null) {
      await showDesignInfo(
        context,
        'Dein Tageseintrag',
        entry == null
            ? 'Für diesen Tag liegt kein Eintrag vor.'
            : dayEntrySummary(entry),
      );
      return;
    }
    final fromLog = _timeline?.logPeriodIds.contains(period.id) == true;
    final adjustedFromLog =
        _timeline?.logAdjustedIds.contains(period.id) == true;
    final edit = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deine dokumentierten Angaben', style: HomeDesign.text(24)),
            if (entry != null) ...[
              const SizedBox(height: 12),
              Text(
                'Log am ${entry.date.display}: ${dayEntrySummary(entry)}',
                style: HomeDesign.text(
                  14,
                  weight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
            if (fromLog || adjustedFromLog) ...[
              const SizedBox(height: 12),
              Text(
                'Diese Anzeige berücksichtigt deine Blutungsangaben im Log. Light, Medium und Heavy starten oder führen die Periode fort; None beendet sie mit dem Vortag als letztem Tag.',
                style: HomeDesign.text(
                  14,
                  color: HomeDesign.muted,
                  weight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Ausgewählter Tag: ${overview.date.display}\n'
              'Beginn: ${period.start.display}\n'
              'Ende: ${period.isOngoing ? 'läuft noch' : period.end?.display ?? 'unbekannt'}',
              style: HomeDesign.text(16, weight: FontWeight.w600, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              overview.kind == PeriodDayKind.overlapping
                  ? 'Mehrere dokumentierte Zeiträume überschneiden sich an diesem Tag. '
                        'Bitte prüfe deine Einträge; der Kreis legt dafür keinen Periodentag fest.'
                  : 'Der Beginn zählt als Tag 1. Am ausgewählten Tag ist deshalb Tag ${overview.dayNumber} seit Beginn. '
                        '${period.isOngoing
                            ? (fromLog || adjustedFromLog ? 'Die zuletzt eingetragene Blutung führt die Periode fort; mit None beendest du sie.' : 'Du hast diese Periode ausdrücklich als noch laufend markiert; der Bogen ist deshalb rot.')
                            : period.end == null
                            ? 'Ein unbekanntes Ende bestätigt nicht, dass die Blutung noch läuft. Du kannst „Periode läuft noch“ beim Bearbeiten aktivieren.'
                            : 'Innerhalb des dokumentierten Periodenzeitraums ist der Bogen rot, danach hellrosa.'}',
              style: HomeDesign.text(
                16,
                color: HomeDesign.ink,
                weight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              overview.estimate == null
                  ? 'Für den Countdown brauchen wir mindestens drei Periodenbeginne, also zwei Abstände. '
                        'Bei widersprüchlichen Zeiträumen wird ebenfalls keine Schätzung angezeigt. '
                        'Es wird keine feste Zykluslänge unterstellt.'
                  : 'Geschätzte Zykluslänge: ${overview.estimate!.lengthInDays} Tage. '
                        'Das ist der Median aus den letzten ${overview.estimate!.cycleCount} Start-zu-Start-Abständen. '
                        'Diese lagen zwischen ${overview.estimate!.shortestInterval} und ${overview.estimate!.longestInterval} Tagen.\n\n'
                        'Geschätzter nächster Beginn: ${overview.estimate!.expectedStart.display}. '
                        'Letzter Beginn + geschätzte Zykluslänge − ausgewählter Tag ergibt den Countdown. '
                        'Der Bogen wächst im geschätzten Zyklus von 0 bis 100 Prozent. '
                        'Der tatsächliche Beginn kann abweichen; ein überschrittener Termin wird nicht automatisch in den nächsten Zyklus verschoben.',
              style: HomeDesign.text(
                14,
                color: HomeDesign.muted,
                weight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: HomeDesign.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Einträge ansehen'),
            ),
          ],
        ),
      ),
    );
    if (edit == true && mounted) await _openDiary();
  }

  void _showPreview({bool recommendations = false}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendations ? 'For you' : 'Designvorschau',
              style: HomeDesign.text(26),
            ),
            const SizedBox(height: 12),
            Text(
              recommendations
                  ? 'Für dich liegen noch keine persönlichen Empfehlungen vor. '
                        'Die Bewegungsideen auf der Startseite sind Beispiele.'
                  : 'Der Kreis und „Logged symptoms“ verwenden deine gespeicherten Angaben für den ausgewählten Tag. '
                        'Weitere Zyklusphasen sind vorläufige Kalenderschätzungen und entsprechend gekennzeichnet. '
                        '„Possible symptoms“ und Bewegungsideen sind allgemeine Beispiele, '
                        'keine Auswertung deiner gespeicherten Einträge.',
              style: HomeDesign.text(
                16,
                color: HomeDesign.ink,
                weight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: HomeDesign.red),
              onPressed: () => Navigator.pop(context),
              child: const Text('Verstanden'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopHero() => LayoutBuilder(
    builder: (context, constraints) {
      final scale = constraints.maxWidth / 412;
      return Stack(
        children: [
          Positioned(
            top: -60 * scale,
            left: 0,
            child: _HomeAsset(
              'header-background',
              width: 412.001 * scale,
              height: 435 * scale,
            ),
          ),
          Column(
            children: [
              SizedBox(height: 20 * scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 26 * scale),
                child: _DateToolbar(
                  scale: scale,
                  selectedDate: _selectedDate,
                  onToday: _selectToday,
                  showToday: false,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 26 * scale),
                child: CurvedDateSlider(
                  scale: scale,
                  selectedDate: _selectedDate,
                  onChanged: _selectDate,
                  showArrows: true,
                ),
              ),
              SizedBox(height: 12 * scale),
              _periodRing(scale),
              SizedBox(height: 24 * scale),
            ],
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: HomeDesign.palePink,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7F9),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return HomeDesktopLayout(
                selectedDate: _selectedDate,
                hero: _desktopHero(),
                information: _informationCards(1.1),
                onToday: _selectToday,
                onCalendar: () => widget.onCalendar(_selectedDate),
                onLog: widget.onLog == null
                    ? () => _openDiary(log: true)
                    : () => widget.onLog!(_selectedDate),
                onForYou:
                    widget.onForYou ??
                    () => _showPreview(recommendations: true),
                onCycle: widget.onCycle ?? () => _openDiary(),
                onDemo: _showPreview,
              );
            }
            final wide = constraints.maxWidth > 600;
            final width = math.min(412.0, constraints.maxWidth);
            final height = wide
                ? math.min(917.0, constraints.maxHeight - 32)
                : constraints.maxHeight;
            final scale = width / 412;
            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kIsWeb || wide ? 30 : 0),
                  child: Material(
                    color: Colors.white,
                    child: Semantics(
                      label:
                          'Kuyena Startseite. Kreis, Phase und Symptome beziehen sich auf den ausgewählten Tag. Schätzungen und Beispiele sind gekennzeichnet.',
                      container: true,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey('home-scroll'),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 17 * scale,
                                    child: const ColoredBox(
                                      color: HomeDesign.red,
                                    ),
                                  ),
                                  Positioned(
                                    top: 16 * scale,
                                    left: 0,
                                    child: _HomeAsset(
                                      'header-background',
                                      width: 412.001 * scale,
                                      height: 435 * scale,
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      _StatusBar(scale: scale),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          26 * scale,
                                          5 * scale,
                                          26 * scale,
                                          0,
                                        ),
                                        child: SizedBox(
                                          height: 55 * scale,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Hey, girl!',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: HomeDesign.text(
                                                    40 * scale,
                                                    color: Colors.white,
                                                    height: 1.375,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: _showPreview,
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor: Colors.white
                                                      .withValues(alpha: 0.14),
                                                  minimumSize: const Size(
                                                    48,
                                                    32,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                ),
                                                child: Text(
                                                  'Demo',
                                                  style: HomeDesign.text(
                                                    12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 26 * scale,
                                        ),
                                        child: _DateToolbar(
                                          scale: scale,
                                          selectedDate: _selectedDate,
                                          onToday: _selectToday,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 26 * scale,
                                        ),
                                        child: CurvedDateSlider(
                                          scale: scale,
                                          selectedDate: _selectedDate,
                                          onChanged: _selectDate,
                                        ),
                                      ),
                                      SizedBox(height: 12 * scale),
                                      _periodRing(scale),
                                      SizedBox(height: 27 * scale),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 26 * scale,
                                        ),
                                        child: _informationCards(scale),
                                      ),
                                      SizedBox(height: 25 * scale),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _BottomNavigation(
                            scale: scale,
                            logLabel: widget.onLog == null
                                ? 'Periode eintragen'
                                : 'Log your day',
                            onHome: _selectToday,
                            onCalendar: () => widget.onCalendar(_selectedDate),
                            onLog: widget.onLog == null
                                ? () => _openDiary(log: true)
                                : () => widget.onLog!(_selectedDate),
                            onForYou:
                                widget.onForYou ??
                                () => _showPreview(recommendations: true),
                            onCycle: widget.onCycle ?? () => _openDiary(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeAsset extends StatelessWidget {
  const _HomeAsset(this.name, {required this.width, required this.height});

  final String name;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/home/$name.svg',
    key: ValueKey('home-asset-$name'),
    width: width,
    height: height,
    excludeFromSemantics: true,
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      // A real phone supplies its own clock and status icons.
      return SizedBox(
        height: math.max(36 * scale, MediaQuery.paddingOf(context).top),
      );
    }
    return ExcludeSemantics(
      child: SizedBox(
        height: 36 * scale,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            26 * scale,
            12 * scale,
            26 * scale,
            2 * scale,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '9:41',
                style: HomeDesign.text(13 * scale, color: Colors.white),
              ),
              Row(
                children: [
                  _HomeAsset(
                    'status-signal',
                    width: 16 * scale,
                    height: 16 * scale,
                  ),
                  SizedBox(width: 5 * scale),
                  _HomeAsset(
                    'status-wifi',
                    width: 16 * scale,
                    height: 16 * scale,
                  ),
                  SizedBox(width: 5 * scale),
                  _HomeAsset(
                    'status-battery',
                    width: 23 * scale,
                    height: 16 * scale,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateToolbar extends StatelessWidget {
  const _DateToolbar({
    required this.scale,
    required this.selectedDate,
    required this.onToday,
    this.showToday = true,
  });
  final double scale;
  final CalendarDate selectedDate;
  final VoidCallback onToday;
  final bool showToday;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28 * scale,
    child: Row(
      children: [
        Expanded(
          child: Text(
            MaterialLocalizations.of(
              context,
            ).formatMonthYear(selectedDate.value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeDesign.text(13 * scale, color: Colors.white),
          ),
        ),
        if (showToday)
          TextButton(
            onPressed: onToday,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: Size(48, 28 * scale),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Heute',
              style: HomeDesign.text(12 * scale, color: Colors.white),
            ),
          ),
      ],
    ),
  );
}

class _InformationCards extends StatelessWidget {
  const _InformationCards({
    required this.scale,
    required this.phase,
    required this.entry,
    required this.isToday,
    required this.loading,
    required this.loadFailed,
    required this.onPhase,
    required this.onSymptoms,
    required this.onMovement,
  });
  final double scale;
  final CyclePhaseOverview phase;
  final DayEntry? entry;
  final bool isToday, loading, loadFailed;
  final VoidCallback onPhase, onSymptoms, onMovement;

  Widget _card({
    Key? key,
    required Widget child,
    required Color color,
    required VoidCallback onTap,
  }) => Material(
    key: key,
    color: color,
    borderRadius: BorderRadius.circular(26 * scale),
    child: InkWell(
      borderRadius: BorderRadius.circular(26 * scale),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12 * scale,
          10 * scale,
          12 * scale,
          10 * scale,
        ),
        child: child,
      ),
    ),
  );

  Widget _information({
    required String heading,
    required String value,
    required String hint,
    double size = 22,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(heading, style: HomeDesign.text(11 * scale, height: 16 / 11)),
      SizedBox(height: 3 * scale),
      Text(value, style: HomeDesign.text(size * scale, height: 1.27)),
      SizedBox(height: 5 * scale),
      Text(hint, style: HomeDesign.text(10.5 * scale, weight: FontWeight.w600)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final symptoms = Symptom.values
        .where((symptom) => entry?.symptoms.contains(symptom) == true)
        .toList();
    final unavailable = loading || loadFailed;
    final status = loading ? 'Loading…' : 'Unavailable';
    final statusHint = loading ? 'Reading your entries' : 'Tap to try again';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _card(
                key: const ValueKey('home-phase-card'),
                color: HomeDesign.palePink,
                onTap: onPhase,
                child: _information(
                  heading: !unavailable && phase.isEstimated
                      ? 'Estimated phase'
                      : isToday
                      ? 'Current phase'
                      : 'Phase on this day',
                  value: unavailable ? status : phaseLabel(phase),
                  hint: unavailable ? statusHint : phaseHint(phase),
                ),
              ),
            ),
            SizedBox(width: 14 * scale),
            Expanded(
              child: _card(
                key: const ValueKey('home-symptoms-card'),
                color: HomeDesign.palePink,
                onTap: onSymptoms,
                child: _information(
                  heading: unavailable
                      ? 'Symptoms'
                      : symptoms.isEmpty
                      ? 'Possible symptoms'
                      : 'Logged symptoms',
                  value: unavailable
                      ? status
                      : symptoms.isEmpty
                      ? 'Cramps'
                      : symptoms.map(symptomLabel).join('\n'),
                  hint: unavailable
                      ? statusHint
                      : symptoms.isEmpty
                      ? 'Example · not a prediction'
                      : 'From your log',
                  size: symptoms.length > 1 ? 18 : 22,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 13 * scale),
        _card(
          color: HomeDesign.pink,
          onTap: onMovement,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested movement',
                style: HomeDesign.text(18 * scale, height: 23 / 18),
              ),
              SizedBox(height: 3 * scale),
              Text(
                'Walking · Swimming · Yoga',
                style: HomeDesign.text(15 * scale),
              ),
              SizedBox(height: 3 * scale),
              Text(
                'Choose what feels right today.',
                style: HomeDesign.text(12 * scale, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.scale,
    required this.logLabel,
    required this.onHome,
    required this.onCalendar,
    required this.onLog,
    required this.onForYou,
    required this.onCycle,
  });
  final double scale;
  final String logLabel;
  final VoidCallback onHome;
  final VoidCallback onCalendar;
  final VoidCallback onLog;
  final VoidCallback onForYou;
  final VoidCallback onCycle;

  Widget _destination(
    String label,
    String icon,
    VoidCallback onTap, {
    bool active = false,
  }) => SizedBox(
    width: 68 * scale,
    child: Semantics(
      selected: active,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('home-nav-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52 * scale,
              height: 32 * scale,
              decoration: BoxDecoration(
                color: active ? HomeDesign.pink : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: _HomeAsset(icon, width: 22 * scale, height: 22 * scale),
            ),
            SizedBox(height: 4 * scale),
            Text(
              label,
              style: HomeDesign.text(
                10.5 * scale,
                color: active ? HomeDesign.red : HomeDesign.muted,
                weight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extra = math.max(0.0, textScale - 1) * 20;
    final bottomInset = kIsWeb ? 0.0 : MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: 144 * scale + extra + bottomInset,
      child: Stack(
        children: [
          Positioned(
            top: 45 * scale,
            left: 0,
            right: 0,
            bottom: 0,
            child: const ColoredBox(color: HomeDesign.palePink),
          ),
          Positioned(
            top: 54 * scale,
            left: 18 * scale,
            right: 18 * scale,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _destination('Home', 'home', onHome, active: true),
                _destination('Calendar', 'calendar', onCalendar),
                SizedBox(
                  width: 68 * scale,
                  child: Padding(
                    padding: EdgeInsets.only(top: 36 * scale),
                    child: Center(
                      child: InkWell(
                        onTap: onLog,
                        child: Text(
                          'Log',
                          style: HomeDesign.text(
                            10.5 * scale,
                            color: HomeDesign.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _destination('For you', 'compass', onForYou),
                _destination('Cycle', 'user', onCycle),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: (412 / 2 - 43) * scale,
            child: Semantics(
              button: true,
              label: logLabel,
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('home-log-button'),
                onTap: onLog,
                borderRadius: BorderRadius.circular(43),
                child: SizedBox(
                  width: 86 * scale,
                  height: 86 * scale,
                  child: Stack(
                    children: [
                      _HomeAsset(
                        'log-halo',
                        width: 86 * scale,
                        height: 86 * scale,
                      ),
                      Positioned(
                        left: 14 * scale,
                        top: 16 * scale,
                        child: _HomeAsset(
                          'log-button',
                          width: 57 * scale,
                          height: 57 * scale,
                        ),
                      ),
                      Positioned(
                        left: 27 * scale,
                        top: 29 * scale,
                        child: _HomeAsset(
                          'log-plus',
                          width: 31.5 * scale,
                          height: 31.5 * scale,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (kIsWeb)
            Positioned(
              bottom: 21 * scale,
              left: (412 / 2 - 64) * scale,
              child: ExcludeSemantics(
                child: Container(
                  width: 128 * scale,
                  height: 4 * scale,
                  decoration: BoxDecoration(
                    color: HomeDesign.ink,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
