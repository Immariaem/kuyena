import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/data/backup/backup_document.dart';
import 'package:kuyena_tracker/data/backup/encrypted_backup.dart';
import 'package:kuyena_tracker/data/storage/local_app_store.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'data_fixture.dart';

void main() {
  late DataFixture f;
  setUp(() => f = DataFixture());
  Future<BackupDocument> example() async {
    await f.diary.add(dataToday.addDays(-2), end: dataToday);
    await f.journal.save(
      DayEntry(
        date: dataToday,
        flow: FlowIntensity.light,
        symptoms: {Symptom.cramps},
        mood: Mood.low,
        energy: 0,
        note: 'Sensitive test note',
      ),
    );
    await f.journal.setReminders(true);
    await f.journal.updatePeriodDays({
      dataToday.addDays(-1): false,
    }, expected: {});
    return BackupDocument(
      periods: await f.diary.load(),
      journal: await f.journal.load(),
    );
  }

  Uint8List bytes(String raw) => Uint8List.fromList(utf8.encode(raw));
  test(
    'Plain export and preview round-trip all original records, corrections and settings without writing',
    () async {
      final document = await example(), service = f.service();
      final raw = await service.jsonExport();
      final before = f.storage.value;
      final preview = await service.preview(bytes(raw));
      expect(f.storage.value, before);
      expect(preview.document.encode(), document.encode());
      expect(preview.document.journal.entries.single.energy, 0);
      expect(preview.document.journal.periodDays.values.single, isFalse);
    },
  );
  test(
    'Confirmed restore replaces both sections in one write and stale previews cannot overwrite changes',
    () async {
      final document = await example(),
          service = f.service(),
          raw = await service.jsonExport();
      await f.store.clear();
      var preview = await service.preview(bytes(raw));
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Newer'));
      final before = f.storage.value;
      await expectLater(
        service.restore(preview),
        throwsA(isA<LocalDataException>()),
      );
      expect(f.storage.value, before);
      preview = await service.preview(bytes(raw));
      await service.restore(preview);
      expect(await service.jsonExport(), document.encode());
      await expectLater(
        service.restore(preview),
        throwsA(isA<LocalDataException>()),
      );
    },
  );
  test(
    'Failed restore retains current period, symptoms, preferences and original serialized data',
    () async {
      final raw = (await example()).encode(), service = f.service();
      await f.store.clear();
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Current'));
      final preview = await service.preview(bytes(raw)),
          before = f.storage.value;
      f.storage.failWrite = true;
      await expectLater(service.restore(preview), throwsStateError);
      expect(f.storage.value, before);
    },
  );
  test(
    'Valid backup can explicitly recover corrupt current storage after preview',
    () async {
      final raw = (await example()).encode(), service = f.service();
      f.storage.value = 'damaged';
      final preview = await service.preview(bytes(raw));
      expect(f.storage.value, 'damaged');
      await service.restore(preview);
      expect(
        (await f.store.load()).journal.entries.single.note,
        'Sensitive test note',
      );
    },
  );
  test(
    'Version one JSON imports missing ongoing and calendar corrections conservatively',
    () {
      final document = BackupDocument.decode(
        jsonEncode({
          'format': 'kuyena-export',
          'version': 1,
          'periods': [
            {'id': 'old', 'start': '2026-10-10', 'end': null},
          ],
          'dayEntries': [],
          'reminders': false,
        }),
        today: dataToday,
      );
      expect(document.periods.single.isOngoing, isFalse);
      expect(document.periods.single.end, isNull);
      expect(document.journal.periodDays, isEmpty);
    },
  );
  test(
    'Unknown formats, duplicate periods/days, invalid dates, future observations and empty entries are rejected',
    () async {
      final valid =
          jsonDecode((await example()).encode()) as Map<String, dynamic>;
      final period = (valid['periods'] as List).single,
          entry = (valid['dayEntries'] as List).single;
      for (final map in [
        {...valid, 'version': 99},
        {...valid, 'format': 'other'},
        {
          ...valid,
          'periods': [period, period],
        },
        {
          ...valid,
          'dayEntries': [entry, entry],
        },
        {
          ...valid,
          'periodDays': [
            {'date': '2026-10-28', 'period': false},
            {'date': '2026-10-28', 'period': true},
          ],
        },
        {
          ...valid,
          'periods': [
            {...period, 'start': '2026-02-30'},
          ],
        },
        {
          ...valid,
          'dayEntries': [
            {...entry, 'date': '2026-10-30'},
          ],
        },
        {
          ...valid,
          'periods': [
            {...period, 'end': '2026-10-30'},
          ],
        },
        {
          ...valid,
          'periodDays': [
            {'date': '2026-10-30', 'period': true},
          ],
        },
        {
          ...valid,
          'dayEntries': [DayEntry(date: dataToday).toJson()],
        },
        {...valid, 'reminders': 'yes'},
      ]) {
        expect(
          () => BackupDocument.decode(jsonEncode(map), today: dataToday),
          throwsA(isA<BackupException>()),
        );
      }
      final before = f.storage.value;
      await expectLater(
        f.service().preview(bytes('not json')),
        throwsA(isA<BackupException>()),
      );
      expect(f.storage.value, before);
    },
  );
  test(
    'Oversized documents and invalid UTF-8 are rejected before any replacement',
    () async {
      final service = f.service();
      final before = f.storage.value;
      await expectLater(
        service.preview(Uint8List(EncryptedBackup.maxFileBytes + 1)),
        throwsA(isA<BackupException>()),
      );
      await expectLater(
        service.preview(Uint8List.fromList([255, 255])),
        throwsA(isA<BackupException>()),
      );
      expect(f.storage.value, before);
    },
  );
  test(
    'Reviewable overlapping manual dates remain reviewable without invented corrections',
    () {
      final raw = jsonEncode({
        'format': 'kuyena-export',
        'version': 2,
        'periods': [
          {
            'id': 'one',
            'start': '2026-10-10',
            'end': '2026-10-15',
            'ongoing': false,
          },
          {
            'id': 'two',
            'start': '2026-10-12',
            'end': '2026-10-16',
            'ongoing': false,
          },
        ],
        'dayEntries': [],
        'reminders': false,
        'periodDays': [],
      });
      expect(BackupDocument.decode(raw, today: dataToday).periods.length, 2);
    },
  );
  test('Password rules accept Unicode and never silently trim', () {
    expect(
      () => EncryptedBackup.validatePassword('short'),
      throwsA(isA<BackupException>()),
    );
    expect(() => EncryptedBackup.validatePassword('🌷' * 12), returnsNormally);
    expect(
      () => EncryptedBackup.validatePassword('a' * 1025),
      throwsA(isA<BackupException>()),
    );
  });
  test(
    'Authenticated encryption round-trips a real backup, randomizes each file and rejects tampering or wrong password',
    () async {
      final document = await example(),
          cipher = EncryptedBackup(),
          password = 'this is a test passphrase';
      final first = await cipher.encrypt(document.encode(), password),
          second = await cipher.encrypt(document.encode(), password);
      expect(first, isNot(equals(second)));
      expect(utf8.decode(first), isNot(contains('Sensitive test note')));
      expect(utf8.decode(first), isNot(contains('2026-10-29')));
      expect(await cipher.decrypt(first, password), document.encode());
      await expectLater(
        cipher.decrypt(first, 'wrong passphrase'),
        throwsA(isA<BackupException>()),
      );
      final altered = jsonDecode(utf8.decode(first)) as Map<String, dynamic>;
      final tag = base64Decode(altered['tag'] as String);
      tag[0] ^= 1;
      altered['tag'] = base64Encode(tag);
      await expectLater(
        cipher.decrypt(bytes(jsonEncode(altered)), password),
        throwsA(isA<BackupException>()),
      );
      final preview = await f.service().preview(first, password: password);
      expect(preview.document.encode(), document.encode());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'Untrusted crypto parameters and bad salt/nonce sizes are rejected before key derivation',
    () async {
      final json = {
        'format': 'kuyena-backup',
        'version': 1,
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': 600000,
        'cipher': 'AES-256-GCM',
        'salt': base64Encode(List.filled(16, 1)),
        'nonce': base64Encode(List.filled(12, 1)),
        'tag': base64Encode(List.filled(16, 1)),
        'ciphertext': base64Encode([1]),
      };
      for (final altered in [
        {...json, 'iterations': 999999999},
        {...json, 'version': 99},
        {...json, 'salt': 'AA=='},
        {...json, 'nonce': 'AA=='},
        {...json, 'tag': 'AA=='},
        {...json, 'cipher': 'unknown'},
      ]) {
        await expectLater(
          EncryptedBackup().decrypt(bytes(jsonEncode(altered)), 'password'),
          throwsA(isA<BackupException>()),
        );
      }
    },
  );
}
