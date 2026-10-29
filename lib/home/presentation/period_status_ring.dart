import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../periods/domain/period_day_overview.dart';
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
    this.bleedingAbsent = false,
  });

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
    final days = overview.daysToNext;
    final countdownValue = days == null
        ? 'Noch offen'
        : days > 0
        ? 'Noch ca. $days ${days == 1 ? 'Tag' : 'Tage'}'
        : days == 0
        ? 'Ca. heute'
        : 'Termin vorbei';
    final countdownDetail = days == null
        ? 'Mindestens 3 Periodenbeginne nötig'
        : days >= 0
        ? 'Schätzung aus deinen Einträgen'
        : 'Geschätzt war ${overview.estimate!.expectedStart.display}\nNeuen Beginn eintragen, sobald bekannt';
    final (title, value, detail) = loading
        ? ('Deine Einträge', 'Laden …', 'Einen Moment bitte')
        : loadFailed
        ? ('Deine Einträge', 'Nicht verfügbar', 'Zum erneuten Laden tippen')
        : overview.hasCountdown
        ? ('Bis zur nächsten Periode', countdownValue, countdownDetail)
        : switch (overview.kind) {
            PeriodDayKind.noEntry => (
              logSummary == null ? 'Dein Überblick' : 'Dein Tag',
              logSummary == null
                  ? 'Kein Eintrag'
                  : bleedingAbsent
                  ? 'Keine Periode'
                  : 'Log gespeichert',
              logSummary == null
                  ? 'Für diesen Tag liegt noch kein Beginn vor'
                  : bleedingAbsent
                  ? 'Keine Blutung eingetragen'
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
              'von ${overview.documentedDuration} dokumentierten Tagen',
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
              SvgPicture.asset(
                'assets/home/cycle-background.svg',
                width: 339 * scale,
                height: 339 * scale,
                excludeFromSemantics: true,
              ),
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(
                    'ring-progress-${overview.period?.id ?? 'none'}',
                  ),
                  tween: Tween(
                    begin: 0,
                    end: loading || loadFailed ? 0 : overview.progress ?? 0,
                  ),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, child) => CustomPaint(
                    painter: PeriodRingPainter(
                      progress: progress,
                      color: overview.isPeriod
                          ? HomeDesign.red
                          : HomeDesign.pink,
                      showStart:
                          !loading &&
                          !loadFailed &&
                          overview.kind != PeriodDayKind.noEntry &&
                          overview.kind != PeriodDayKind.overlapping,
                    ),
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
  const PeriodRingPainter({
    required this.progress,
    required this.color,
    required this.showStart,
  });
  final double progress;
  final Color color;
  final bool showStart;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.385;
    final stroke = size.shortestSide * 0.075;
    if (!showStart) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (progress <= 0) {
      canvas.drawCircle(
        Offset(center.dx, center.dy - radius),
        stroke / 2,
        Paint()..color = color,
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(PeriodRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.showStart != showStart;
}
