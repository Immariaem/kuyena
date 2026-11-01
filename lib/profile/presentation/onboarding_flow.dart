import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../home/presentation/home_design.dart';
import '../../journal/domain/day_entry.dart';
import '../../journal/presentation/day_entry_labels.dart';
import '../../periods/domain/calendar_date.dart';
import '../../data/storage/local_app_store.dart';
import '../application/profile_controller.dart';
import '../domain/user_profile.dart';
import 'onboarding_frame.dart';
import 'privacy_page.dart';

/// One form is reused during first setup and later in Cycle & App.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.controller,
    this.editing = false,
    this.initialSection,
    this.onFinished,
    this.onEditPeriods,
  });
  final ProfileController controller;
  final bool editing;
  final int? initialSection;
  final VoidCallback? onFinished;
  final Future<void> Function()? onEditPeriods;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late UserProfile? _baseline;
  late Map<String, dynamic> _answers;
  final _exact = TextEditingController(),
      _excluded = TextEditingController(),
      _limits = TextEditingController(),
      _allergies = TextEditingController(),
      _dislikes = TextEditingController();
  int _page = 0;
  bool _busy = false, _dirty = false, _returnToSummary = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _baseline = widget.controller.value;
    _answers = Map<String, dynamic>.from(
      (_baseline ??
              UserProfile(
                lastPeriodStart: widget.controller.latestStart,
                lastPeriodEnd: widget.controller.latestEnd,
                lastPeriodOngoing: widget.controller.latestOngoing,
                dailyReminder: widget.controller.legacyReminders ? true : null,
              ))
          .toJson(),
    );
    _page = widget.editing
        ? (widget.initialSection ?? 8)
        : (_baseline?.step ?? 0);
    _returnToSummary = widget.editing && _page != 8;
    _exact.text = _answers['exactCycleDays']?.toString() ?? '';
    _excluded.text = _answers['excludedActivities'];
    _limits.text = _answers['limitations'];
    _allergies.text = _answers['otherAllergies'];
    _dislikes.text = _answers['dislikedIngredients'];
    _dirty = false;
  }

  @override
  void dispose() {
    for (final c in [_exact, _excluded, _limits, _allergies, _dislikes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String key, Object? value) => setState(() {
    _answers[key] = value;
    if (key == 'lastPeriodStart') {
      if (value == null ||
          (_answers['lastPeriodEnd'] != null &&
              CalendarDate.parse(
                    _answers['lastPeriodEnd'],
                  ).compareTo(CalendarDate.parse(value as String)) <
                  0)) {
        _answers['lastPeriodEnd'] = null;
      }
      if (value == null) _answers['lastPeriodOngoing'] = false;
    }
    if (key == 'lastPeriodEnd') _answers['lastPeriodOngoing'] = false;
    if (key == 'lastPeriodOngoing' && value == true) {
      _answers['lastPeriodEnd'] = null;
    }
    if ((key == 'lastPeriodStart' || key == 'lastPeriodEnd') &&
        _lastDuration != null) {
      final d = _lastDuration!;
      _answers['periodLength'] = d == 1
          ? 'single'
          : d <= 3
          ? 'short'
          : d <= 5
          ? 'medium'
          : d <= 7
          ? 'long'
          : 'extended';
    }
    _dirty = true;
    _error = null;
  });
  int? get _lastDuration =>
      _answers['lastPeriodStart'] == null || _answers['lastPeriodEnd'] == null
      ? null
      : CalendarDate.parse(
              _answers['lastPeriodStart'],
            ).daysUntil(CalendarDate.parse(_answers['lastPeriodEnd'])) +
            1;
  UserProfile _profile({required bool completed, required int step}) {
    final raw = _exact.text.trim();
    if (raw.isNotEmpty &&
        (int.tryParse(raw) == null ||
            int.parse(raw) < 1 ||
            int.parse(raw) > 366)) {
      throw const FormatException(
        'Bitte gib eine Zykluslänge zwischen 1 und 366 Tagen ein oder lasse die genaue Zahl frei.',
      );
    }
    return UserProfile.fromJson({
      ..._answers,
      'completed': completed,
      'step': step,
      'exactCycleDays': raw.isEmpty ? null : int.parse(raw),
      'excludedActivities': _excluded.text.trim(),
      'limitations': _limits.text.trim(),
      'otherAllergies': _allergies.text.trim(),
      'dislikedIngredients': _dislikes.text.trim(),
    });
  }

  Future<void> _next({bool skip = false}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final finish = _page == 8;
      final next = _returnToSummary ? 8 : _page + 1;
      final profile = _profile(
        completed: finish || widget.editing,
        step: finish ? 8 : next,
      );
      // Editing remains a draft until the summary Save button is pressed.
      if (!widget.editing || finish) {
        await widget.controller.save(profile, expected: _baseline);
        _baseline = profile;
      }
      if (!mounted) return;
      if (finish) {
        _dirty = false;
        if (widget.editing) {
          Navigator.pop(context, true);
        } else {
          widget.onFinished?.call();
        }
      } else {
        setState(() {
          _answers = Map<String, dynamic>.from(profile.toJson());
          _page = next;
          _returnToSummary = false;
          if (!widget.editing) _dirty = false;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on LocalDataException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Speichern hat nicht geklappt. Deine Auswahl bleibt hier. Bitte versuche es erneut.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back() async {
    if (_busy) return;
    if (widget.editing && (_page == 8 || _returnToSummary)) {
      if (_page != 8) {
        setState(() {
          _page = 8;
          _returnToSummary = false;
        });
        return;
      }
      if (await _leave() && mounted) {
        Navigator.pop(context);
      }
    } else if (_page > 0) {
      setState(() => _page--);
    }
  }

  Future<bool> _leave() async {
    if (_busy) return false;
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Änderungen verwerfen?'),
            content: const Text(
              'Deine letzten Änderungen sind noch nicht gespeichert.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Weiter bearbeiten'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Verwerfen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _edit(int page) => setState(() {
    _page = page;
    _returnToSummary = true;
    _error = null;
  });
  Future<void> _reload() async {
    if (!await _leave() || !mounted) return;
    try {
      await widget.controller.load();
      if (mounted) {
        setState(() {
          _init();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Die Einstellungen konnten nicht geladen werden.',
        );
      }
    }
  }

  Widget _question(String title, Widget child, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: HomeDesign.text(17, height: 1.4)),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint,
            style: HomeDesign.text(
              13,
              color: HomeDesign.muted,
              weight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
  Widget _choice(
    String key,
    String label,
    Object? value, {
    bool multiple = false,
    bool unknown = false,
  }) {
    final selected =
        key == 'lastPeriodEnd' && _answers['lastPeriodOngoing'] == true
        ? false
        : multiple
        ? (_answers[key] as List).contains(value)
        : _answers[key] == value;
    return Semantics(
      selected: selected,
      child: FilterChip(
        key: ValueKey('profile-$key-${value ?? 'unknown'}'),
        label: Text(label),
        selected: selected,
        onSelected: _busy
            ? null
            : (_) {
                if (multiple) {
                  final list = List<String>.from(_answers[key]);
                  if (list.contains(value)) {
                    list.remove(value);
                  } else {
                    if (key == 'allergies') {
                      if (value == 'none') {
                        list.clear();
                        _allergies.clear();
                      } else {
                        list.remove('none');
                      }
                    }
                    list.add(value as String);
                  }
                  _set(key, list);
                } else {
                  _set(key, value);
                  if (key == 'cycleLength') {
                    _exact.clear();
                  }
                }
              },
        showCheckmark: true,
        checkmarkColor: Colors.white,
        backgroundColor: HomeDesign.palePink,
        selectedColor: HomeDesign.red,
        labelStyle: HomeDesign.text(
          15,
          color: selected ? Colors.white : HomeDesign.red,
          weight: FontWeight.w700,
        ),
        side: BorderSide(
          color: selected
              ? HomeDesign.red
              : unknown
              ? HomeDesign.pink
              : Colors.transparent,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }

  Widget _choices(
    String key,
    Map<String, String> options, {
    bool multiple = false,
    String? unknown,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final e in options.entries)
        _choice(key, e.value, e.key, multiple: multiple),
      if (unknown != null) _choice(key, unknown, null, unknown: true),
    ],
  );
  Widget _yesNo(String key) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _choice(key, 'Ja', true),
      _choice(key, 'Nein', false),
      _choice(key, 'Später entscheiden', null, unknown: true),
    ],
  );
  Widget _text(
    TextEditingController controller,
    String key,
    String hint, {
    int lines = 1,
  }) => TextField(
    key: ValueKey('profile-$key'),
    controller: controller,
    enabled: !_busy,
    maxLength: 2000,
    minLines: lines,
    maxLines: lines + 2,
    onChanged: (_) {
      setState(() {
        _dirty = true;
        _error = null;
        if (key == 'otherAllergies' && controller.text.trim().isNotEmpty) {
          _answers['allergies'] = List<String>.from(_answers['allergies'])
            ..remove('none');
        }
      });
    },
    style: HomeDesign.text(15, color: HomeDesign.ink, weight: FontWeight.w600),
    decoration: InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: HomeDesign.palePink,
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
    ),
  );
  Future<void> _date({bool end = false}) async {
    final today = widget.controller.today();
    final start = _answers['lastPeriodStart'] == null
        ? null
        : CalendarDate.parse(_answers['lastPeriodStart']);
    if (end && start == null) return;
    final raw = _answers[end ? 'lastPeriodEnd' : 'lastPeriodStart'] as String?;
    final initial = raw == null
        ? (end ? start!.value : today.value)
        : CalendarDate.parse(raw).value;
    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: end ? start!.value : DateTime(1900),
      lastDate: today.value,
      helpText: end ? 'Letzter Blutungstag' : 'Letzter Periodenbeginn',
    );
    if (chosen != null) {
      _set(
        end ? 'lastPeriodEnd' : 'lastPeriodStart',
        CalendarDate.fromDateTime(chosen).iso,
      );
    }
  }

  Widget _dateButton({required bool end}) {
    final raw = _answers[end ? 'lastPeriodEnd' : 'lastPeriodStart'] as String?;
    return OutlinedButton(
      key: ValueKey(end ? 'profile-end-date' : 'profile-start-date'),
      onPressed: _busy || (end && _answers['lastPeriodStart'] == null)
          ? null
          : () => _date(end: end),
      style: OutlinedButton.styleFrom(
        backgroundColor: HomeDesign.palePink,
        side: BorderSide.none,
        padding: const EdgeInsets.all(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              raw == null
                  ? (end && _answers['lastPeriodOngoing'] == true
                        ? 'Periode läuft noch'
                        : 'tt.mm.jjjj')
                  : CalendarDate.parse(raw).display,
              style: HomeDesign.text(17),
            ),
          ),
          const Icon(
            Icons.calendar_today_outlined,
            color: HomeDesign.ink,
            size: 22,
          ),
        ],
      ),
    );
  }

  Future<void> _editPeriod() async {
    await widget.onEditPeriods?.call();
    if (mounted) setState(() {});
  }

  Widget _cycle() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!widget.editing) ...[
        _question(
          'Wann hat deine letzte Periode begonnen?',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dateButton(end: false),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _choice(
                  'lastPeriodStart',
                  'Weiß ich nicht',
                  null,
                  unknown: true,
                ),
              ),
            ],
          ),
        ),
        _question(
          'Wann war der letzte Tag deiner Periode?',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dateButton(end: true),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice(
                    'lastPeriodEnd',
                    'Weiß ich nicht',
                    null,
                    unknown: true,
                  ),
                  if (_answers['lastPeriodStart'] != null)
                    _choice('lastPeriodOngoing', 'Periode läuft noch', true),
                ],
              ),
              if (_lastDuration != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Deine letzte Periode dauerte $_lastDuration ${_lastDuration == 1 ? 'Tag' : 'Tage'}.',
                    key: const ValueKey('profile-calculated-duration'),
                    style: HomeDesign.text(16),
                  ),
                ),
            ],
          ),
          hint:
              'Beginn und letzter Blutungstag zählen mit. Der ganze Zeitraum wird im Kalender eingetragen. Ein unbekanntes Ende wird nicht geschätzt.',
        ),
      ] else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            widget.controller.latestStart == null
                ? 'Noch kein Periodenzeitraum eingetragen.'
                : 'Letzte Periode: ${widget.controller.latestStart!.display} – ${widget.controller.latestOngoing ? 'läuft noch' : widget.controller.latestEnd?.display ?? 'Ende unbekannt'}',
            style: HomeDesign.text(15),
          ),
        ),
        if (widget.onEditPeriods != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('profile-edit-period-range'),
              onPressed: _busy ? null : _editPeriod,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Periodenzeitraum bearbeiten'),
            ),
          ),
        const SizedBox(height: 16),
      ],
      _question(
        'Wie lange dauert deine Periode normalerweise?',
        _choices(
          'periodLength',
          ProfileOptions.periodLengths,
          unknown: 'Weiß ich nicht',
        ),
        hint: _lastDuration == null
            ? null
            : 'Aus dem eingetragenen Zeitraum vorbelegt. Du kannst deine übliche Dauer trotzdem ändern.',
      ),
      _question(
        'Wie lang ist dein Zyklus normalerweise?',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _choices(
              'cycleLength',
              ProfileOptions.cycleLengths,
              unknown: 'Weiß ich nicht',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('profile-exact-cycle'),
              controller: _exact,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: (_) => setState(() {
                _dirty = true;
                final v = int.tryParse(_exact.text);
                if (v != null) {
                  _answers['cycleLength'] = v < 24
                      ? 'short'
                      : v <= 28
                      ? 'medium'
                      : v <= 32
                      ? 'long'
                      : 'extended';
                }
              }),
              style: HomeDesign.text(16),
              decoration: InputDecoration(
                labelText: 'Genaue Tageszahl, falls bekannt',
                hintText: 'z. B. 28',
                filled: true,
                fillColor: HomeDesign.palePink,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wenn du keine genaue Zykluslänge weißt, starten wir vorläufig mit einem allgemeinen Richtwert von 28 Tagen. Mit weiteren Periodenbeginnen verwenden wir deinen persönlichen Mittelwert. Ein gewählter Bereich wird nicht in eine erfundene genaue Zahl umgerechnet.',
              style: HomeDesign.text(
                12,
                color: HomeDesign.muted,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      _question(
        'Wie regelmäßig ist dein Zyklus ungefähr?',
        _choices(
          'regularity',
          ProfileOptions.regularity,
          unknown: 'Weiß ich nicht',
        ),
      ),
    ],
  );
  Widget _goals() => Column(
    children: [
      for (final e in ProfileOptions.goals.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            selected: (_answers['goals'] as List).contains(e.key),
            child: Material(
              color: (_answers['goals'] as List).contains(e.key)
                  ? HomeDesign.red
                  : HomeDesign.palePink,
              borderRadius: BorderRadius.circular(26),
              child: InkWell(
                key: ValueKey('profile-goal-${e.key}'),
                borderRadius: BorderRadius.circular(26),
                onTap: _busy
                    ? null
                    : () {
                        final l = List<String>.from(_answers['goals']);
                        l.contains(e.key) ? l.remove(e.key) : l.add(e.key);
                        _set('goals', l);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.value,
                          style: HomeDesign.text(
                            18,
                            color: (_answers['goals'] as List).contains(e.key)
                                ? Colors.white
                                : HomeDesign.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        (_answers['goals'] as List).contains(e.key)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: (_answers['goals'] as List).contains(e.key)
                            ? Colors.white
                            : HomeDesign.pink,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
  Widget _tracking() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _question(
        'Welche Symptome möchtest du beobachten?',
        _choices('symptoms', {
          for (final s in Symptom.values) s.name: symptomLabelDe(s),
        }, multiple: true),
        hint:
            'Mehrfachauswahl möglich. Im Log bleiben auch alle anderen Symptome erreichbar.',
      ),
      _question(
        'Möchtest du Stimmung und Energie ebenfalls tracken?',
        _yesNo('trackMoodEnergy'),
      ),
      _question('Möchtest du Notizen hinzufügen können?', _yesNo('trackNotes')),
    ],
  );
  Widget _movement() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _question(
        'Welche Bewegungsarten magst du?',
        _choices('movements', ProfileOptions.movements, multiple: true),
      ),
      _question(
        'Wie aktiv bist du im Alltag?',
        _choices('activity', ProfileOptions.activity, unknown: 'Keine Angabe'),
      ),
      _question(
        'Was interessiert dich?',
        _choices('interests', ProfileOptions.interests, multiple: true),
      ),
      _question(
        'Gibt es Aktivitäten, die du nicht möchtest?',
        _text(_excluded, 'excludedActivities', 'z. B. Laufen oder Sprünge'),
      ),
      _question(
        'Gibt es Verletzungen oder Einschränkungen, die wir berücksichtigen sollen?',
        _text(
          _limits,
          'limitations',
          'Nur so viel, wie du teilen möchtest',
          lines: 2,
        ),
        hint:
            'Freiwillig. Diese Angabe ist eine Präferenz und keine medizinische Beurteilung. Individuell geprüfte Trainingspläne gibt es hier noch nicht.',
      ),
    ],
  );
  Widget _nutrition() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _question(
        'Welche Ernährungsweise bevorzugst du?',
        _choices('diet', ProfileOptions.diets, unknown: 'Keine Angabe'),
      ),
      _question(
        'Gibt es Allergien oder Unverträglichkeiten?',
        _choices('allergies', ProfileOptions.allergies, multiple: true),
        hint:
            'Mehrfachauswahl möglich. „Keine“ lässt sich nicht mit einer Allergie kombinieren.',
      ),
      _question(
        'Weitere Allergien oder Unverträglichkeiten',
        _text(_allergies, 'otherAllergies', 'Optional ergänzen'),
      ),
      _question(
        'Gibt es Zutaten, die du nicht magst?',
        _text(_dislikes, 'dislikedIngredients', 'z. B. Koriander, Pilze'),
      ),
      Text(
        'Die bisherigen Rezeptideen sind allgemeine Inhalte. Bitte prüfe Zutaten selbst; eine automatische Allergieprüfung ist noch nicht verfügbar.',
        style: HomeDesign.text(
          12,
          color: HomeDesign.muted,
          weight: FontWeight.w600,
        ),
      ),
    ],
  );
  Widget _reminders() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _question(
        'Möchtest du an tägliches Tracking erinnert werden?',
        _yesNo('dailyReminder'),
      ),
      _question(
        'Möchtest du eine Erinnerung vor der geschätzten Periode?',
        _yesNo('periodReminder'),
        hint:
            'Bis zu zwei Tage vorher, sobald ein geschätzter nächster Beginn vorliegt.',
      ),
      _question(
        'Zu welcher Uhrzeit möchtest du Erinnerungen erhalten?',
        OutlinedButton(
          key: const ValueKey('profile-reminder-time'),
          onPressed: _busy
              ? null
              : () async {
                  final minute = _answers['reminderMinute'] as int;
                  final t = await showTimePicker(
                    context: context,
                    initialEntryMode: TimePickerEntryMode.input,
                    initialTime: TimeOfDay(
                      hour: minute ~/ 60,
                      minute: minute % 60,
                    ),
                    helpText: 'Erinnerungszeit',
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (t != null) _set('reminderMinute', t.hour * 60 + t.minute);
                },
          style: OutlinedButton.styleFrom(
            backgroundColor: HomeDesign.palePink,
            side: BorderSide.none,
            padding: const EdgeInsets.all(18),
          ),
          child: Row(
            children: [
              Expanded(child: Text(_time(), style: HomeDesign.text(24))),
              const Icon(Icons.schedule, color: HomeDesign.ink),
            ],
          ),
        ),
      ),
      Text(
        'Derzeit erscheinen Hinweise nur in der geöffneten App ab dieser Uhrzeit. Auf dem Sperrbildschirm und bei geschlossener App werden noch keine Benachrichtigungen verschickt. Dafür wird jetzt keine Systemberechtigung angefragt.',
        style: HomeDesign.text(
          13,
          color: HomeDesign.muted,
          weight: FontWeight.w600,
        ),
      ),
    ],
  );
  String _time() {
    final m = _answers['reminderMinute'] as int;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  String _selected(String key, Map<String, String> options) =>
      List<String>.from(_answers[key]).map((v) => options[v] ?? v).join(', ');
  String _answer(String key) => _answers[key] == null
      ? 'Später entscheiden'
      : _answers[key] == true
      ? 'Ja'
      : 'Nein';
  Widget _summaryCard(String title, String value, int page) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: HomeDesign.palePink,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        key: ValueKey('profile-summary-$page'),
        onTap: _busy ? null : () => _edit(page),
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HomeDesign.text(16)),
                    const SizedBox(height: 6),
                    Text(
                      value.isEmpty ? 'Keine Angabe' : value,
                      style: HomeDesign.text(
                        14,
                        color: HomeDesign.muted,
                        weight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: HomeDesign.red,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _summary() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _summaryCard(
        'Zyklusdaten',
        [
          if (!widget.editing && _answers['lastPeriodStart'] != null)
            'Beginn: ${CalendarDate.parse(_answers['lastPeriodStart']).display}',
          if (!widget.editing && _answers['lastPeriodEnd'] != null)
            'Ende: ${CalendarDate.parse(_answers['lastPeriodEnd']).display}',
          if (!widget.editing && _lastDuration != null)
            'Letzte Periodendauer: $_lastDuration Tage',
          if (!widget.editing && _answers['lastPeriodOngoing'] == true)
            'Periode läuft noch',
          if (_answers['periodLength'] != null)
            'Periodendauer: ${ProfileOptions.periodLengths[_answers['periodLength']]}',
          if (_answers['cycleLength'] != null)
            'Zyklus: ${ProfileOptions.cycleLengths[_answers['cycleLength']]}',
          if (_exact.text.trim().isNotEmpty)
            'Richtwert: ${_exact.text.trim()} Tage',
          if (_answers['regularity'] != null)
            ProfileOptions.regularity[_answers['regularity']]!,
        ].join('\n'),
        2,
      ),
      _summaryCard('Ziele', _selected('goals', ProfileOptions.goals), 3),
      _summaryCard(
        'Symptome & Tracking',
        [
          if ((_answers['symptoms'] as List).isNotEmpty)
            _selected('symptoms', {
              for (final s in Symptom.values) s.name: symptomLabelDe(s),
            }),
          'Stimmung & Energie: ${_answer('trackMoodEnergy')}',
          'Notizen: ${_answer('trackNotes')}',
        ].join('\n'),
        4,
      ),
      _summaryCard(
        'Bewegung',
        [
          _selected('movements', ProfileOptions.movements),
          if (_answers['activity'] != null)
            ProfileOptions.activity[_answers['activity']]!,
          _selected('interests', ProfileOptions.interests),
          if (_excluded.text.trim().isNotEmpty)
            'Nicht gewünscht: ${_excluded.text.trim()}',
          if (_limits.text.trim().isNotEmpty)
            'Einschränkungen: ${_limits.text.trim()}',
        ].where((s) => s.isNotEmpty).join('\n'),
        5,
      ),
      _summaryCard(
        'Ernährung',
        [
          if (_answers['diet'] != null) ProfileOptions.diets[_answers['diet']]!,
          _selected('allergies', ProfileOptions.allergies),
          _allergies.text.trim(),
          if (_dislikes.text.trim().isNotEmpty)
            'Ungern: ${_dislikes.text.trim()}',
        ].where((s) => s.isNotEmpty).join('\n'),
        6,
      ),
      _summaryCard(
        'Erinnerungen',
        'Tägliches Tracking: ${_answer('dailyReminder')}\nVor der Periode: ${_answer('periodReminder')}\n${_time()} · nur innerhalb der geöffneten App',
        7,
      ),
      const SizedBox(height: 6),
      Text(
        'Bei wenigen Daten sind Vorhersagen besonders unsicher. Zunächst nutzen wir deine genaue Zykluslänge oder einen allgemeinen Startwert von 28 Tagen. Mit dokumentierten Startabständen verwenden wir deinen persönlichen Mittelwert. Mehr Daten garantieren keine höhere Genauigkeit. Das Eisprungfenster bleibt eine grobe Schätzung.',
        style: HomeDesign.text(
          13,
          color: HomeDesign.muted,
          weight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    ],
  );
  Widget _privacyCard(String title, String text) => Container(
    margin: const EdgeInsets.only(bottom: 22),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: HomeDesign.palePink,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          'assets/onboarding/privacy-dot.svg',
          width: 44,
          height: 44,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: HomeDesign.text(
                  15,
                  color: Colors.black,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: HomeDesign.text(
                  15,
                  color: Colors.black,
                  weight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _privacy() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _privacyCard(
        'Deine Daten bleiben bei dir',
        'Deine Einträge bleiben lokal auf deinem Gerät bzw. in diesem Browser. Die App sendet sie nicht an einen Kuyena-Server.',
      ),
      _privacyCard(
        'Kein Konto nötig',
        'Du brauchst keine E-Mail-Adresse und kein Konto-Passwort. Es gibt keine automatische Synchronisation zwischen Geräten.',
      ),
      _privacyCard(
        'Du hast die Kontrolle',
        'Du kannst deine Angaben jederzeit ändern oder löschen und selbst eine Sicherung erstellen.',
      ),
      TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
        ),
        child: Text(
          'Unsere Datenschutzinformationen',
          style: HomeDesign.text(14, weight: FontWeight.w600),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final titles = [
      'Willkommen',
      'Willkommen',
      'Zyklusdaten',
      'Ziele & Interessen',
      'Symptome & Tracking',
      'Sport & Bewegung',
      'Ernährung & Rezepte',
      'Erinnerungen',
      'Zusammenfassung',
    ];
    final subtitles = [
      'Verstehe deinen Zyklus besser.',
      'Dein Körper. Deine Daten. Deine Entscheidung.',
      'Ungefähre Angaben reichen völlig.',
      'Was möchtest du mit der App erreichen? Mehrfachauswahl möglich.',
      'Du kannst alles später unter „Cycle & App“ ändern.',
      'Was passt zu dir und deinem Alltag?',
      'Deine Vorlieben für passende Rezeptideen.',
      'Sanfte Hinweise, ganz wie du magst.',
      'Prüfe deine Angaben – du kannst sie jederzeit ändern.',
    ];
    final content = switch (_page) {
      0 => Text(
        'Lerne deinen Körper in deinem eigenen Tempo kennen.',
        style: HomeDesign.text(34, color: Colors.black, height: 1.12),
      ),
      1 => _privacy(),
      2 => _cycle(),
      3 => _goals(),
      4 => _tracking(),
      5 => _movement(),
      6 => _nutrition(),
      7 => _reminders(),
      _ => _summary(),
    };
    final label = _page == 0
        ? 'Mehr erfahren'
        : _page == 1
        ? 'Los geht’s'
        : _page == 8
        ? (widget.editing ? 'Änderungen speichern' : 'App starten')
        : _returnToSummary
        ? 'Zur Übersicht'
        : 'Weiter';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: OnboardingFrame(
        title: titles[_page],
        subtitle: subtitles[_page],
        step: _page >= 2 ? _page - 1 : null,
        onBack: _page > 0 || widget.editing ? _back : null,
        welcome: _page == 0,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: HomeDesign.text(13)),
              ),
              TextButton(
                onPressed: _busy ? null : _reload,
                child: const Text('Einstellungen neu laden'),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              height: 58,
              child: FilledButton(
                key: const ValueKey('onboarding-next'),
                onPressed: _busy ? null : _next,
                style: FilledButton.styleFrom(
                  backgroundColor: _page == 0
                      ? HomeDesign.palePink
                      : HomeDesign.red,
                  foregroundColor: _page == 0 ? HomeDesign.red : Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  _busy ? 'Speichern …' : label,
                  style: HomeDesign.text(
                    18,
                    color: _page == 0 ? HomeDesign.red : Colors.white,
                  ),
                ),
              ),
            ),
            if (_page >= 2 && _page < 8 && !_returnToSummary)
              TextButton(
                onPressed: _busy ? null : () => _next(skip: true),
                child: Text(
                  'Überspringen',
                  style: HomeDesign.text(
                    14,
                    color: HomeDesign.muted,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            if (widget.editing)
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _leave() && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                child: Text('Abbrechen', style: HomeDesign.text(14)),
              ),
          ],
        ),
        child: content,
      ),
    );
  }
}
