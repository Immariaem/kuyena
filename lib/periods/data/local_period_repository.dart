import 'dart:convert';

import '../domain/calendar_date.dart';
import '../domain/period.dart';
import '../domain/period_repository.dart';

/// Storage port: permits testing failures without a device plugin.
abstract interface class PeriodStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

final class PeriodDataException implements Exception {
  const PeriodDataException();
}

/// Versioned document for periods, including the optional last day.
/// Unexpected or damaged data is preserved rather than replaced with an empty list.
final class LocalPeriodRepository implements PeriodRepository {
  const LocalPeriodRepository(this.storage);
  final PeriodStorage storage;

  @override
  Future<List<Period>> load() async {
    final raw = await storage.read();
    if (raw == null) return const [];
    try {
      final document = jsonDecode(raw);
      if (document is! Map<String, dynamic>) {
        throw const PeriodDataException();
      }
      final periods = <Period>[];
      if (document['version'] == 1 && document['starts'] is List) {
        // Reading old records does not write or delete anything. Their IDs
        // remain stable until the next explicit save writes version 2.
        for (final value in document['starts'] as List) {
          if (value is! String) throw const PeriodDataException();
          final start = CalendarDate.parse(value);
          periods.add(Period(id: 'legacy-${start.iso}', start: start));
        }
      } else if (document['version'] == 2 && document['periods'] is List) {
        for (final value in document['periods'] as List) {
          if (value is! Map<String, dynamic> ||
              value['id'] is! String ||
              value['start'] is! String ||
              !value.containsKey('end') ||
              (value['end'] != null && value['end'] is! String)) {
            throw const PeriodDataException();
          }
          periods.add(
            Period(
              id: value['id'] as String,
              start: CalendarDate.parse(value['start'] as String),
              end: value['end'] == null
                  ? null
                  : CalendarDate.parse(value['end'] as String),
            ),
          );
        }
      } else {
        throw const PeriodDataException();
      }
      _validateUnique(periods);
      return List.unmodifiable(periods);
    } on FormatException {
      throw const PeriodDataException();
    } on ArgumentError {
      throw const PeriodDataException();
    }
  }

  void _validateUnique(List<Period> periods) {
    if (periods.map((period) => period.id).toSet().length != periods.length ||
        periods.map((period) => period.start).toSet().length !=
            periods.length) {
      throw const PeriodDataException();
    }
  }

  @override
  Future<void> save(List<Period> periods) async {
    _validateUnique(periods);
    final encoded = jsonEncode({
      'version': 2,
      'periods': periods
          .map(
            (period) => {
              'id': period.id,
              'start': period.start.iso,
              'end': period.end?.iso,
            },
          )
          .toList(),
    });
    await storage.write(encoded);
    // Verify the platform accepted the value before reporting success to the UI.
    if (await storage.read() != encoded) {
      throw StateError('Speichern konnte nicht bestätigt werden.');
    }
  }

  @override
  Future<void> clear() async {
    await storage.delete();
    if (await storage.read() != null) {
      throw StateError('Löschen konnte nicht bestätigt werden.');
    }
  }
}
