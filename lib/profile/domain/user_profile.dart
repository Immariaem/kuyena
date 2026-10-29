import 'dart:convert';
import '../../journal/domain/day_entry.dart';
import '../../periods/domain/calendar_date.dart';

abstract final class ProfileOptions {
  static const periodLengths = {
    'short': '2–3 Tage',
    'medium': '4–5 Tage',
    'long': '6–7 Tage',
    'extended': '8+ Tage',
  };
  static const cycleLengths = {
    'short': '< 24 Tage',
    'medium': '24–28 Tage',
    'long': '29–32 Tage',
    'extended': '33+ Tage',
  };
  static const regularity = {
    'regular': 'Sehr regelmäßig',
    'mostly': 'Meistens regelmäßig',
    'irregular': 'Unregelmäßig',
  };
  static const goals = {
    'understand': 'Zyklus verstehen',
    'symptoms': 'Symptome erkennen',
    'lifestyle': 'Bewegung und Ernährung anpassen',
    'patterns': 'Muster im eigenen Zyklus erkennen',
  };
  static const movements = {
    'yoga': 'Yoga',
    'walking': 'Spazieren',
    'running': 'Laufen',
    'swimming': 'Schwimmen',
    'cycling': 'Radfahren',
    'pilates': 'Pilates',
    'dancing': 'Tanzen',
    'strength': 'Krafttraining',
    'stretching': 'Stretching',
  };
  static const activity = {
    'low': 'Wenig aktiv',
    'moderate': 'Mäßig aktiv',
    'high': 'Sehr aktiv',
  };
  static const interests = {
    'relaxation': 'Entspannung',
    'gentle': 'Sanfte Bewegung',
    'endurance': 'Ausdauer',
    'strength': 'Krafttraining',
  };
  static const diets = {
    'all': 'Alles',
    'vegetarian': 'Vegetarisch',
    'vegan': 'Vegan',
    'pescatarian': 'Pescetarisch',
  };
  static const allergies = {
    'none': 'Keine',
    'lactose': 'Laktose',
    'gluten': 'Gluten',
    'nuts': 'Nüsse',
    'soy': 'Soja',
    'eggs': 'Eier',
    'fructose': 'Fructose',
  };
}

/// Self-reported preferences. Unknown stays null/empty, never a medical default.
final class UserProfile {
  UserProfile({
    this.completed = false,
    this.step = 0,
    this.lastPeriodStart,
    this.periodLength,
    this.cycleLength,
    this.exactCycleDays,
    this.regularity,
    Set<String> goals = const {},
    Set<Symptom> symptoms = const {},
    this.trackMoodEnergy,
    this.trackNotes,
    Set<String> movements = const {},
    this.activity,
    Set<String> interests = const {},
    this.excludedActivities = '',
    this.limitations = '',
    this.diet,
    Set<String> allergies = const {},
    this.otherAllergies = '',
    this.dislikedIngredients = '',
    this.dailyReminder,
    this.periodReminder,
    this.reminderMinute = 1200,
  }) : goals = Set.unmodifiable(goals),
       symptoms = Set.unmodifiable(symptoms),
       movements = Set.unmodifiable(movements),
       interests = Set.unmodifiable(interests),
       allergies = Set.unmodifiable(allergies) {
    if (step < 0 ||
        step > 8 ||
        reminderMinute < 0 ||
        reminderMinute >= 1440 ||
        (exactCycleDays != null &&
            (exactCycleDays! < 1 || exactCycleDays! > 366))) {
      throw const FormatException('Ungültige Profileinstellung.');
    }
    _choice(periodLength, ProfileOptions.periodLengths);
    _choice(cycleLength, ProfileOptions.cycleLengths);
    _choice(regularity, ProfileOptions.regularity);
    _choice(activity, ProfileOptions.activity);
    _choice(diet, ProfileOptions.diets);
    _choices(this.goals, ProfileOptions.goals);
    _choices(this.movements, ProfileOptions.movements);
    _choices(this.interests, ProfileOptions.interests);
    _choices(this.allergies, ProfileOptions.allergies);
    if (this.allergies.contains('none') && this.allergies.length > 1) {
      throw const FormatException('Widersprüchliche Allergieangaben.');
    }
    for (final text in [
      excludedActivities,
      limitations,
      otherAllergies,
      dislikedIngredients,
    ]) {
      if (text.length > 2000) {
        throw const FormatException('Maximal 2000 Zeichen je Textfeld.');
      }
    }
  }
  static void _choice(String? value, Map<String, String> choices) {
    if (value != null && !choices.containsKey(value)) {
      throw const FormatException('Unbekannte Auswahl.');
    }
  }

  static void _choices(Set<String> values, Map<String, String> choices) {
    for (final value in values) {
      _choice(value, choices);
    }
  }

  final bool completed;
  final int step, reminderMinute;

  /// Only used to create the explicitly reported first start on completion.
  /// Later date corrections belong to the calendar, not to preferences.
  final CalendarDate? lastPeriodStart;
  final String? periodLength, cycleLength, regularity, activity, diet;
  final int? exactCycleDays;
  final Set<String> goals, movements, interests, allergies;
  final Set<Symptom> symptoms;
  final bool? trackMoodEnergy, trackNotes, dailyReminder, periodReminder;
  final String excludedActivities,
      limitations,
      otherAllergies,
      dislikedIngredients;
  Map<String, Object?> toJson() => {
    'version': 1,
    'completed': completed,
    'step': step,
    'lastPeriodStart': lastPeriodStart?.iso,
    'periodLength': periodLength,
    'cycleLength': cycleLength,
    'exactCycleDays': exactCycleDays,
    'regularity': regularity,
    'goals': goals.toList()..sort(),
    'symptoms': symptoms.map((s) => s.name).toList()..sort(),
    'trackMoodEnergy': trackMoodEnergy,
    'trackNotes': trackNotes,
    'movements': movements.toList()..sort(),
    'activity': activity,
    'interests': interests.toList()..sort(),
    'excludedActivities': excludedActivities,
    'limitations': limitations,
    'diet': diet,
    'allergies': allergies.toList()..sort(),
    'otherAllergies': otherAllergies,
    'dislikedIngredients': dislikedIngredients,
    'dailyReminder': dailyReminder,
    'periodReminder': periodReminder,
    'reminderMinute': reminderMinute,
  };
  String encode() => jsonEncode(toJson());
  factory UserProfile.decode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) throw const FormatException();
      return UserProfile.fromJson(j);
    } on TypeError {
      throw const FormatException('Ungültige Profileinstellungen.');
    } on ArgumentError {
      throw const FormatException('Ungültige Profileinstellungen.');
    }
  }
  factory UserProfile.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1 ||
        j['completed'] is! bool ||
        j['step'] is! int ||
        j['reminderMinute'] is! int) {
      throw const FormatException();
    }
    // Require every field, including explicit null for unknown answers.
    final template = UserProfile().toJson();
    if (!template.keys.every(j.containsKey)) throw const FormatException();
    for (final key in [
      'trackMoodEnergy',
      'trackNotes',
      'dailyReminder',
      'periodReminder',
    ]) {
      if (j[key] != null && j[key] is! bool) throw const FormatException();
    }
    for (final key in [
      'periodLength',
      'cycleLength',
      'regularity',
      'activity',
      'diet',
      'lastPeriodStart',
    ]) {
      if (j[key] != null && j[key] is! String) throw const FormatException();
    }
    for (final key in [
      'excludedActivities',
      'limitations',
      'otherAllergies',
      'dislikedIngredients',
    ]) {
      if (j[key] is! String) throw const FormatException();
    }
    if (j['exactCycleDays'] != null && j['exactCycleDays'] is! int) {
      throw const FormatException();
    }
    Set<String> strings(String key) {
      final v = j[key];
      if (v is! List ||
          v.any((x) => x is! String) ||
          v.toSet().length != v.length) {
        throw const FormatException();
      }
      return v.cast<String>().toSet();
    }

    return UserProfile(
      completed: j['completed'],
      step: j['step'],
      lastPeriodStart: j['lastPeriodStart'] == null
          ? null
          : CalendarDate.parse(j['lastPeriodStart']),
      periodLength: j['periodLength'],
      cycleLength: j['cycleLength'],
      exactCycleDays: j['exactCycleDays'],
      regularity: j['regularity'],
      goals: strings('goals'),
      symptoms: strings('symptoms').map(Symptom.values.byName).toSet(),
      trackMoodEnergy: j['trackMoodEnergy'],
      trackNotes: j['trackNotes'],
      movements: strings('movements'),
      activity: j['activity'],
      interests: strings('interests'),
      excludedActivities: j['excludedActivities'],
      limitations: j['limitations'],
      diet: j['diet'],
      allergies: strings('allergies'),
      otherAllergies: j['otherAllergies'],
      dislikedIngredients: j['dislikedIngredients'],
      dailyReminder: j['dailyReminder'],
      periodReminder: j['periodReminder'],
      reminderMinute: j['reminderMinute'],
    );
  }
  UserProfile copyWith({bool? completed, int? step}) => UserProfile.fromJson({
    ...toJson(),
    'completed': ?completed,
    'step': ?step,
  });
}
