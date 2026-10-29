import '../../data/storage/data_lock.dart';
import 'dart:math';

import '../domain/calendar_date.dart';
import '../domain/period.dart';
import '../domain/period_repository.dart';

final class PeriodRuleException implements Exception {
  const PeriodRuleException(this.message);
  final String message;
}

/// Executes use cases. The repository is supplied from outside for testing.
final class PeriodDiary {
  PeriodDiary({
    required this.repository,
    DateTime Function()? clock,
    String Function()? idGenerator,
    DataLock? dataLock,
  }) : dataLock = dataLock ?? DataLock(),
       clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _newId;

  final PeriodRepository repository;
  final DateTime Function() clock;
  final String Function() _idGenerator;
  final DataLock dataLock;
  CalendarDate get today => CalendarDate.fromDateTime(clock());
  Future<T> synchronized<T>(Future<T> Function() operation) =>
      dataLock.run(operation);
  Future<T> _run<T>(Future<T> Function() operation) => synchronized(operation);

  static String _newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'period-$hex';
  }

  List<Period> _sorted(Iterable<Period> periods) {
    final result = periods.toList()..sort((a, b) => b.start.compareTo(a.start));
    return List.unmodifiable(result);
  }

  void _validate(CalendarDate start, CalendarDate? end) {
    final currentDay = today;
    if (start.compareTo(currentDay) > 0) {
      throw const PeriodRuleException(
        'Ein Periodenbeginn darf nicht in der Zukunft liegen.',
      );
    }
    if (end != null && end.compareTo(currentDay) > 0) {
      throw const PeriodRuleException(
        'Ein Periodenende darf nicht in der Zukunft liegen.',
      );
    }
  }

  Future<List<Period>> load() =>
      _run(() async => _sorted(await repository.load()));

  Future<List<Period>> add(
    CalendarDate start, {
    CalendarDate? end,
    bool isOngoing = false,
  }) => _run(() async {
    _validate(start, end);
    final periods = await repository.load();
    if (periods.any((period) => period.start == start)) {
      throw const PeriodRuleException(
        'Für diesen Tag besteht bereits ein Eintrag.',
      );
    }
    final Period period;
    try {
      period = Period(
        id: _idGenerator(),
        start: start,
        end: end,
        isOngoing: isOngoing,
      );
    } on ArgumentError catch (error) {
      throw PeriodRuleException(error.message.toString());
    }
    if (periods.any((existing) => existing.id == period.id)) {
      throw StateError('Es konnte keine neue Kennung vergeben werden.');
    }
    final updated = _sorted([...periods, period]);
    await repository.save(updated);
    return updated;
  });

  Future<List<Period>> correct(
    String id,
    CalendarDate start, {
    required CalendarDate? end,
    bool? isOngoing,
    Period? expected,
  }) => _run(() async {
    _validate(start, end);
    final periods = await repository.load();
    final index = periods.indexWhere((period) => period.id == id);
    if (index == -1) {
      throw const PeriodRuleException(
        'Dieser Eintrag ist nicht mehr vorhanden. Bitte lade den Verlauf neu.',
      );
    }
    if (periods.any((period) => period.id != id && period.start == start)) {
      throw const PeriodRuleException(
        'Für diesen Tag besteht bereits ein Eintrag.',
      );
    }
    if (expected != null && !_same(periods[index], expected)) {
      throw const PeriodRuleException(
        'Dieser Periodeneintrag wurde inzwischen geändert. Bitte lade den Verlauf neu.',
      );
    }
    final Period corrected;
    try {
      corrected = periods[index].correctDates(
        start: start,
        end: end,
        isOngoing: isOngoing,
      );
    } on ArgumentError catch (error) {
      throw PeriodRuleException(error.message.toString());
    }
    final updated = _sorted([
      for (final period in periods) period.id == id ? corrected : period,
    ]);
    await repository.save(updated);
    return updated;
  });

  Future<List<Period>> remove(String id, {Period? expected}) => _run(() async {
    final periods = await repository.load();
    if (!periods.any((period) => period.id == id)) {
      throw const PeriodRuleException(
        'Dieser Eintrag ist nicht mehr vorhanden. Bitte lade den Verlauf neu.',
      );
    }
    if (expected != null &&
        !_same(periods.firstWhere((p) => p.id == id), expected)) {
      throw const PeriodRuleException(
        'Dieser Periodeneintrag wurde inzwischen geändert. Bitte lade den Verlauf neu.',
      );
    }
    final updated = _sorted(periods.where((period) => period.id != id));
    if (updated.isEmpty) {
      await repository.clear();
    } else {
      await repository.save(updated);
    }
    return updated;
  });

  bool _same(Period a, Period b) =>
      a.id == b.id &&
      a.start == b.start &&
      a.end == b.end &&
      a.isOngoing == b.isOngoing;

  Future<List<Period>> clear() => _run(() async {
    await repository.clear();
    return const <Period>[];
  });
}
