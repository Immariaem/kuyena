import 'package:flutter/material.dart';
import '../../home/presentation/home_design.dart';
import '../../periods/domain/cycle_display.dart';

/// Forecast details shown on demand in the calendar information sheet.
class CalendarForecast extends StatelessWidget {
  const CalendarForecast({super.key, required this.cycle});
  final CycleDisplay cycle;
  @override
  Widget build(BuildContext context) {
    final estimate = cycle.day.estimate;
    if (estimate == null) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('calendar-forecast'),
      padding: const EdgeInsets.only(top: 4, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cycle.nextPeriodEnd == null
                ? 'Nächste Periode ≈ ${estimate.expectedStart.display}'
                : 'Nächste Periode ≈ ${estimate.expectedStart.display} – ${cycle.nextPeriodEnd!.display}${cycle.periodEndOpen ? ' …' : ''}',
            key: const ValueKey('forecast-next-period'),
            style: HomeDesign.text(15),
          ),
          if (cycle.durationBasis != null) ...[
            const SizedBox(height: 3),
            Text(
              cycle.durationBasis!,
              style: HomeDesign.text(
                11,
                color: HomeDesign.muted,
                weight: FontWeight.w600,
              ),
            ),
          ],
          if (cycle.fertileStart != null) ...[
            const SizedBox(height: 4),
            Text(
              'Möglicherweise fruchtbar ≈ ${cycle.fertileStart!.display} – ${cycle.ovulationEnd!.display}',
              style: HomeDesign.text(12, weight: FontWeight.w600),
            ),
          ],
          if (cycle.ovulationStart != null) ...[
            const SizedBox(height: 4),
            Text(
              'Eisprungfenster ≈ ${cycle.ovulationStart!.display} – ${cycle.ovulationEnd!.display}',
              key: const ValueKey('forecast-ovulation'),
              style: HomeDesign.text(13, weight: FontWeight.w600),
            ),
          ],
          if ((cycle.day.daysToNext ?? 0) < 0) ...[
            const SizedBox(height: 4),
            Text(
              'Der geschätzte Termin liegt zurück. Ergänze den neuen Beginn, sobald bekannt.',
              style: HomeDesign.text(12, weight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            '${estimate.basisLabel}\nKalenderschätzung, kein bestätigter Eisprung. Nicht zur Verhütung geeignet.',
            style: HomeDesign.text(
              11,
              color: HomeDesign.muted,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
