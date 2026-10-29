import '../domain/day_entry.dart';

String symptomLabel(Symptom s) => switch (s) {
  Symptom.cramps => 'Cramps',
  Symptom.headache => 'Headache',
  Symptom.fatigue => 'Fatigue',
  Symptom.breastTenderness => 'Breast tenderness',
  Symptom.bloating => 'Bloating',
  Symptom.skinChanges => 'Skin changes',
  Symptom.backPain => 'Back pain',
  Symptom.nausea => 'Nausea',
  Symptom.cravings => 'Cravings',
  Symptom.sleepProblems => 'Sleep problems',
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

String dayEntrySummary(
  DayEntry e, {
  bool compact = false,
  bool includeFlow = true,
}) => [
  if (includeFlow && e.flow != null) 'Flow: ${flowLabel(e.flow!)}',
  if (e.symptoms.isNotEmpty) e.symptoms.map(symptomLabel).join(', '),
  if (e.mood != null) 'Mood: ${moodLabel(e.mood!)}',
  if (e.energy != null) 'Energy: ${e.energy}/100',
  if (!compact && e.note.isNotEmpty) e.note,
  if (compact && e.note.isNotEmpty) 'Notiz',
].join(' · ');

String symptomLabelDe(Symptom s) => switch (s) {
  Symptom.cramps => 'Krämpfe',
  Symptom.headache => 'Kopfschmerzen',
  Symptom.fatigue => 'Müdigkeit',
  Symptom.breastTenderness => 'Brustspannen',
  Symptom.bloating => 'Blähungen',
  Symptom.skinChanges => 'Hautveränderungen',
  Symptom.backPain => 'Rückenschmerzen',
  Symptom.nausea => 'Übelkeit',
  Symptom.cravings => 'Heißhunger',
  Symptom.sleepProblems => 'Schlafprobleme',
};
