import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../periods/domain/period_day_overview.dart';
import '../../periods/domain/calendar_date.dart';
import '../../periods/domain/cycle_display.dart';
import 'home_design.dart';

class PeriodStatusRing extends StatelessWidget {
  const PeriodStatusRing({
    super.key,
    required this.scale,
    required this.overview,
    required this.isToday,
    required this.loading,
    required this.loadFailed,
    required this.onTap,
    this.logSummary,
    this.asOf,
    this.bleedingAbsent = false,
  });

  final CalendarDate? asOf;
  final String? logSummary;
  final bool bleedingAbsent;
  final double scale;
  final PeriodDayOverview overview;
  final bool isToday;
  final bool loading;
  final bool loadFailed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cycle = CycleDisplay.fromDay(overview, asOf: asOf);
    final days = overview.daysToNext;
    final countdownValue = days == null
        ? 'Noch offen'
        : days > 0
        ? 'Noch ca. $days ${days == 1 ? 'Tag' : 'Tage'}'
        : days == 0
        ? 'Ca. heute'
        : 'Termin vorbei';
    final countdownDetail = days == null
        ? 'Zykluslänge oder weitere Beginne ergänzen'
        : days >= 0
        ? overview.estimate!.isInitial
              ? overview.estimate!.isPopulationReference
                    ? 'Vorläufig mit 28 Tagen'
                    : 'Schätzung mit deinem Richtwert'
              : 'Mittelwert deiner Startabstände'
        : 'Geschätzt war ${overview.estimate!.expectedStart.display}\nNeuen Beginn eintragen, sobald bekannt';
    final (title, value, detail) = loading
        ? ('Deine Einträge', 'Laden …', 'Einen Moment bitte')
        : loadFailed
        ? ('Deine Einträge', 'Nicht verfügbar', 'Zum erneuten Laden tippen')
        : overview.hasCountdown && cycle.beforeOvulation
        ? (
            'Bis zum Eisprungfenster',
            'Noch ca. ${cycle.daysToOvulation} ${cycle.daysToOvulation == 1 ? 'Tag' : 'Tage'}',
            'Geschätzt · Zyklustag ${overview.dayNumber}',
          )
        : overview.hasCountdown && cycle.inOvulationWindow
        ? (
            'Eisprungfenster',
            'Ungefähr jetzt',
            '${cycle.ovulationStart!.display} – ${cycle.ovulationEnd!.display}\nKalenderschätzung',
          )
        : overview.hasCountdown
        ? ('Bis zur nächsten Periode', countdownValue, countdownDetail)
        : switch (overview.kind) {
            PeriodDayKind.noEntry => (
              logSummary == null ? 'Dein Überblick' : 'Dein Tag',
              bleedingAbsent
                  ? 'Keine Periode'
                  : logSummary == null
                  ? 'Kein Eintrag'
                  : 'Log gespeichert',
              bleedingAbsent
                  ? 'Keine Blutung eingetragen'
                  : logSummary == null
                  ? 'Für diesen Tag liegt noch kein Beginn vor'
                  : 'Deine Angaben sind gespeichert',
            ),
            PeriodDayKind.unknownEnd => (
              'Bis zur nächsten Periode',
              countdownValue,
              'Ende unbekannt\n$countdownDetail',
            ),
            PeriodDayKind.ongoingPeriod => (
              'Deine Periode',
              'Tag ${overview.dayNumber}',
              'Periode läuft noch',
            ),
            PeriodDayKind.documentedPeriod => (
              'Deine Periode',
              'Tag ${overview.dayNumber}',
              overview.period!.excludedDays.isEmpty
                  ? 'von ${overview.documentedDuration} dokumentierten Tagen'
                  : '${overview.period!.documentedDayCount} eingetragene Blutungstage',
            ),
            PeriodDayKind.afterPeriod => (
              'Bis zur nächsten Periode',
              countdownValue,
              countdownDetail,
            ),
            PeriodDayKind.overlapping => (
              'Deine Einträge',
              'Angaben prüfen',
              'Mehrere Perioden überschneiden sich',
            ),
          };
    final dateLabel = isToday ? 'Heute' : 'Am ${overview.date.display}';
    return Semantics(
      button: true,
      label:
          '$dateLabel. $title. $value. $detail. ${logSummary ?? ''} Details anzeigen.',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('period-status-ring'),
        borderRadius: BorderRadius.circular(200),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 339 * scale,
          height: 339 * scale,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PeriodRingPainter(
                    days: loading || loadFailed ? const [] : cycle.days,
                    selectedIndex: loading || loadFailed
                        ? null
                        : cycle.selectedIndex,
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(62 * scale),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dateLabel,
                        textAlign: TextAlign.center,
                        style: HomeDesign.text(
                          12 * scale,
                          weight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10 * scale),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: HomeDesign.text(14 * scale),
                      ),
                      SizedBox(height: 2 * scale),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          key: const ValueKey('period-day-value'),
                          maxLines: 1,
                          style: HomeDesign.text(40 * scale, height: 1.375),
                        ),
                      ),
                      SizedBox(height: 7 * scale),
                      Flexible(
                        child: Text(
                          detail,
                          textAlign: TextAlign.center,
                          style: HomeDesign.text(
                            12 * scale,
                            weight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (logSummary != null && !loading && !loadFailed) ...[
                        SizedBox(height: 6 * scale),
                        Text(
                          'Log: $logSummary',
                          key: const ValueKey('ring-log-summary'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: HomeDesign.text(
                            11 * scale,
                            weight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeriodRingPainter extends CustomPainter {
  const PeriodRingPainter({required this.days, required this.selectedIndex});
  final List<CycleDayType> days;
  final int? selectedIndex;

  static Color colorFor(CycleDayType day) => switch (day) {
    CycleDayType.period => HomeDesign.red,
    CycleDayType.estimatedOvulation => HomeDesign.ovulationPink,
    CycleDayType.estimatedFertile => HomeDesign.pink,
    CycleDayType.rest => HomeDesign.cycleRest,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.shortestSide / 2,
      Paint()..color = HomeDesign.palePink,
    );
    final radius = size.shortestSide * 0.405;
    final stroke = size.shortestSide * 0.075;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, arc..color = HomeDesign.cycleRest);
    if (days.isEmpty) return;
    // Sample colours at day centres. Neighbouring colours blend smoothly,
    // including across midnight at the top, without changing any day data.
    final seam = Color.lerp(colorFor(days.last), colorFor(days.first), 0.5)!;
    arc.shader = SweepGradient(
      transform: const GradientRotation(-math.pi / 2),
      colors: [seam, for (final day in days) colorFor(day), seam],
      stops: [
        0,
        for (var i = 0; i < days.length; i++) (i + 0.5) / days.length,
        1,
      ],
    ).createShader(rect);
    canvas.drawCircle(center, radius, arc);
    final index = selectedIndex;
    if (index == null) return;
    final angle = -math.pi / 2 + 2 * math.pi * (index + 0.5) / days.length;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(point, stroke * 0.42, Paint()..color = Colors.white);
    canvas.drawCircle(point, stroke * 0.23, Paint()..color = HomeDesign.red);
  }

  @override
  bool shouldRepaint(PeriodRingPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      !listEquals(oldDelegate.days, days);
}
