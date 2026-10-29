import 'dart:convert';
import 'dart:typed_data';
import '../../periods/domain/calendar_date.dart';
import '../backup/backup_document.dart';
import '../backup/encrypted_backup.dart';
import '../storage/local_app_store.dart';

final class RestorePreview {
  const RestorePreview._(this.document, this.revision);
  final BackupDocument document;
  final String revision;
}

final class DataBackupService {
  DataBackupService({
    required this.store,
    required this.today,
    EncryptedBackup? encryption,
  }) : encryption = encryption ?? EncryptedBackup();
  final LocalAppStore store;
  final CalendarDate Function() today;
  final EncryptedBackup encryption;
  Future<String> jsonExport() async {
    final data = await store.load();
    return BackupDocument(
      periods: data.periods,
      journal: data.journal,
      profile: data.profile,
    ).encode();
  }

  Future<Uint8List> create(String password) async =>
      encryption.encrypt(await jsonExport(), password);
  Future<RestorePreview> preview(Uint8List bytes, {String? password}) async {
    if (bytes.length > EncryptedBackup.maxFileBytes) {
      throw const BackupException('Die Sicherungsdatei ist zu groß.');
    }
    late String raw;
    if (EncryptedBackup.isEncrypted(bytes)) {
      if (password == null) {
        throw const BackupException(
          'Bitte gib das Passwort dieser Sicherung ein.',
        );
      }
      raw = await encryption.decrypt(bytes, password);
    } else {
      try {
        raw = utf8.decode(bytes);
      } on FormatException {
        throw const BackupException(
          'Die Datei enthält kein gültiges Kuyena-Format.',
        );
      }
    }
    final document = BackupDocument.decode(raw, today: today());
    // Can also recover a damaged current document after explicit review.
    final revision = await store.fingerprint();
    return RestorePreview._(document, revision);
  }

  Future<void> restore(RestorePreview preview) {
    // Recheck civil dates if the device date/timezone changed since the review.
    final checked = BackupDocument.decode(
      preview.document.encode(),
      today: today(),
    );
    return store.replace(
      periods: checked.periods,
      journal: checked.journal,
      profile: checked.profile,
      expectedRevision: preview.revision,
    );
  }
}
