import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';

import '../support/memory_period_storage.dart';

void main() {
  final start = CalendarDate(2026, 10, 3);
  final end = CalendarDate(2026, 10, 7);

  test('Fehlendes Dokument ergibt einen leeren Verlauf', () async {
    expect(await LocalPeriodRepository(MemoryPeriodStorage()).load(), isEmpty);
  });

  test(
    'Neues Repository liest Kennung, Beginn und optionales Ende unverändert',
    () async {
      final storage = MemoryPeriodStorage();
      await LocalPeriodRepository(storage).save([
        Period(id: 'a', start: start, end: end),
        Period(id: 'b', start: CalendarDate(2026, 9, 3)),
      ]);
      final periods = await LocalPeriodRepository(storage).load();
      expect(
        (periods[0].id, periods[0].start, periods[0].end),
        ('a', start, end),
      );
      expect(
        (periods[1].id, periods[1].start, periods[1].end),
        ('b', CalendarDate(2026, 9, 3), null),
      );
    },
  );

  test(
    'Alte Beginne werden ohne Schreibzugriff geladen und beim Bearbeiten übernommen',
    () async {
      const legacy = '{"version":1,"starts":["2026-10-03","2026-09-03"]}';
      final storage = MemoryPeriodStorage(legacy)..failWrite = true;
      final repository = LocalPeriodRepository(storage);
      final periods = await repository.load();
      expect(storage.value, legacy);
      expect(periods.map((p) => p.start.iso), ['2026-10-03', '2026-09-03']);
      expect(periods.every((p) => p.end == null), isTrue);
      expect(
        (await repository.load()).map((p) => p.id),
        periods.map((p) => p.id),
      );

      storage.failWrite = false;
      await repository.save([
        periods.first.correctDates(start: CalendarDate(2026, 10, 2), end: end),
        periods.last,
      ]);
      expect((jsonDecode(storage.value!) as Map)['version'], 3);
      final reloaded = await LocalPeriodRepository(storage).load();
      expect(
        (reloaded.first.id, reloaded.first.start.iso, reloaded.first.end),
        (periods.first.id, '2026-10-02', end),
      );
      expect(
        (reloaded.last.id, reloaded.last.start.iso, reloaded.last.end),
        (periods.last.id, '2026-09-03', null),
      );
    },
  );

  test(
    'Beschädigte und unbekannte Formate bleiben bei einem Lesefehler erhalten',
    () async {
      for (final raw in [
        'kaputt',
        '',
        'null',
        '[]',
        '{"version":4,"periods":[]}',
        '{"version":2,"starts":[]}',
        '{"version":1,"starts":["2026-02-31"]}',
        '{"version":1,"starts":[17]}',
        '{"version":1,"starts":["2026-10-18","2026-10-18"]}',
        '{"version":2,"periods":[{"id":"a","start":"2026-10-03"}]}',
        '{"version":2,"periods":[{"id":"","start":"2026-10-03","end":null}]}',
        '{"version":2,"periods":[{"id":"a","start":"2026-10-03","end":17}]}',
        '{"version":2,"periods":[{"id":"a","start":"2026-10-03","end":"2026-10-02"}]}',
        '{"version":2,"periods":[{"id":"a","start":"2026-10-03","end":null},{"id":"a","start":"2026-09-03","end":null}]}',
        '{"version":2,"periods":[{"id":"a","start":"2026-10-03","end":null},{"id":"b","start":"2026-10-03","end":null}]}',
      ]) {
        final storage = MemoryPeriodStorage(raw);
        await expectLater(
          LocalPeriodRepository(storage).load(),
          throwsA(isA<PeriodDataException>()),
          reason: raw,
        );
        expect(storage.value, raw);
      }
    },
  );

  test(
    'Doppelte Kennungen oder Beginne werden vor dem Schreiben abgelehnt',
    () async {
      final storage = MemoryPeriodStorage();
      final repository = LocalPeriodRepository(storage);
      await repository.save([Period(id: 'a', start: start, end: end)]);
      final before = storage.value;
      for (final invalid in [
        [Period(id: 'a', start: start), Period(id: 'a', start: end)],
        [Period(id: 'a', start: start), Period(id: 'b', start: start)],
      ]) {
        await expectLater(
          repository.save(invalid),
          throwsA(isA<PeriodDataException>()),
        );
        expect(storage.value, before);
      }
    },
  );

  test(
    'Nicht tatsächlich übernommene Schreibvorgänge ergeben keinen Erfolg',
    () async {
      final repository = LocalPeriodRepository(_IgnoringWriteStorage());
      await expectLater(
        repository.save([Period(id: 'a', start: start)]),
        throwsStateError,
      );
    },
  );

  test(
    'Version 2 bleibt unbekannt statt automatisch laufend; Version 3 bewahrt die Bestätigung',
    () async {
      const old =
          '{"version":2,"periods":[{"id":"a","start":"2026-10-03","end":null}]}';
      final storage = MemoryPeriodStorage(old);
      final repository = LocalPeriodRepository(storage);
      final original = (await repository.load()).single;
      expect(original.isOngoing, isFalse);
      expect(storage.value, old);
      await repository.save([
        original.correctDates(
          start: original.start,
          end: null,
          isOngoing: true,
        ),
      ]);
      expect(
        (await LocalPeriodRepository(storage).load()).single.isOngoing,
        isTrue,
      );
      expect((jsonDecode(storage.value!) as Map)['version'], 3);
    },
  );

  test(
    'Ungültige laufende Bestätigung in Version 3 bleibt unverändert erhalten',
    () async {
      for (final raw in [
        '{"version":3,"periods":[{"id":"a","start":"2026-10-03","end":null}]}',
        '{"version":3,"periods":[{"id":"a","start":"2026-10-03","end":null,"ongoing":"yes"}]}',
        '{"version":3,"periods":[{"id":"a","start":"2026-10-03","end":"2026-10-05","ongoing":true}]}',
      ]) {
        final storage = MemoryPeriodStorage(raw);
        await expectLater(
          LocalPeriodRepository(storage).load(),
          throwsA(isA<PeriodDataException>()),
        );
        expect(storage.value, raw);
      }
    },
  );
}

class _IgnoringWriteStorage implements PeriodStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}
