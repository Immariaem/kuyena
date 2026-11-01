import '../../periods/domain/cycle_phase_overview.dart';

String phaseLabel(CyclePhaseOverview overview) => switch (overview.phase) {
  CyclePhase.menstruation => 'Menstruation',
  CyclePhase.follicular => 'Follicular phase',
  CyclePhase.aroundOvulation => 'Around ovulation',
  CyclePhase.luteal => 'Luteal phase',
  CyclePhase.unknown => 'Phase unknown',
};

String phaseHint(CyclePhaseOverview overview) {
  if (overview.isEstimated) return 'Calendar estimate';
  if (overview.phase == CyclePhase.menstruation) return 'Based on your entries';
  return switch (overview.unknownReason) {
    PhaseUnknownReason.noPeriod ||
    PhaseUnknownReason.insufficientHistory => 'Not enough data',
    PhaseUnknownReason.unknownEnd => 'Period end is unknown',
    PhaseUnknownReason.predictionReached => 'Next start not logged',
    _ => 'Check your entries',
  };
}

String phaseExplanation(CyclePhaseOverview overview) {
  if (overview.phase == CyclePhase.menstruation) {
    return 'Deine gespeicherten Perioden- und Blutungsangaben ordnen diesen Tag deiner Periode zu. '
        'Der Beginn zählt als Tag 1; ein eingetragenes Ende ist der letzte Blutungstag. '
        'Start und Ende kannst du auf Home getrennt von deinen Symptomen erfassen.';
  }
  if (overview.isEstimated) {
    return 'Das ist eine vorläufige Kalenderschätzung. Die nächste Periode wird aus '
        'dem Mittelwert deiner dokumentierten Abstände zwischen Periodenbeginnen geschätzt. '
        'Solange noch kein Abstand vorliegt, verwenden wir deine genaue übliche Zykluslänge oder vorläufig einen allgemeinen 28-Tage-Startwert. '
        'Als grobe Orientierung liegt „Around ovulation“ 10–16 Tage vor diesem geschätzten Beginn '
        '(${overview.earliestOvulation!.display} bis ${overview.latestOvulation!.display}). '
        'Davor wird nach dem dokumentierten Periodenende die Follikelphase, danach die Lutealphase geschätzt. '
        'Die tatsächliche Phase oder ein Eisprung lassen sich damit nicht bestätigen. '
        'Eine Periodenschätzung ist keine zuverlässige Eisprung- oder Fruchtbarkeitsbestimmung und eignet sich nicht zur Verhütung.';
  }
  return switch (overview.unknownReason) {
    PhaseUnknownReason.noPeriod =>
      'Für diesen Tag gibt es noch keinen zugehörigen Periodenbeginn. '
          'Symptome allein werden nicht zur Bestimmung einer Zyklusphase verwendet.',
    PhaseUnknownReason.conflictingPeriods =>
      'Gespeicherte Perioden überlappen sich. Bitte prüfe die Einträge, bevor eine Phase geschätzt wird.',
    PhaseUnknownReason.unknownEnd =>
      'Das Ende der zugehörigen Periode ist noch unbekannt. Daraus lässt sich nicht ableiten, ob du noch blutest. '
          'Du kannst das Ende ergänzen oder die Blutung im Log dokumentieren.',
    PhaseUnknownReason.insufficientHistory =>
      'Nach deiner Periode fehlen noch genügend vergangene Zyklen für eine Schätzung. '
          'Du kannst deine genaue übliche Zykluslänge unter „Cycle & App“ ergänzen. Alternativ genügt ein dokumentierter Startabstand. '
          'Bis dahin wird keine weitere Phase angenommen.',
    PhaseUnknownReason.predictionReached =>
      'Der geschätzte nächste Periodenbeginn ist erreicht oder vorbei. '
          'Ohne neuen Eintrag wird kein neuer Zyklus angenommen. Die Schätzung kann abweichen.',
    _ =>
      'Die vorhandenen Datumsangaben lassen sich mit dieser vorläufigen Kalenderschätzung nicht sinnvoll einordnen. '
          'Es wird keine Phase angenommen.',
  };
}
