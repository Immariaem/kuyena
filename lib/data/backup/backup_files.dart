import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'backup_document.dart';
import 'encrypted_backup.dart';

/// Injectable file boundary: cancellation is distinct from an I/O failure.
class BackupFiles {
  Future<bool> save(String filename, Uint8List bytes) async =>
      await FilePicker.saveFile(
        fileName: filename,
        bytes: bytes,
        dialogTitle: 'Kuyena-Sicherung speichern',
      ) !=
      null;
  Future<Uint8List?> pick() async {
    // File extensions are a convenience only; the complete content is validated.
    final file = await FilePicker.pickFile(
      dialogTitle: 'Kuyena-Sicherung auswählen',
    );
    if (file == null) return null;
    final length = await file.length();
    if (length == null) {
      throw const BackupException(
        'Die Dateigröße konnte nicht bestimmt werden.',
      );
    }
    if (length > EncryptedBackup.maxFileBytes) {
      throw const BackupException('Die Sicherungsdatei ist zu groß.');
    }
    final builder = BytesBuilder(copy: false);
    int size = 0;
    await for (final chunk in file.readAsByteStream()) {
      size += chunk.length;
      if (size > EncryptedBackup.maxFileBytes) {
        throw const BackupException('Die Sicherungsdatei ist zu groß.');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
