import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'backup_document.dart';

/// Portable authenticated backup: PBKDF2-HMAC-SHA256 (600k), AES-256-GCM.
/// Parameters are fixed per format version, bounded before any KDF work.
class EncryptedBackup {
  static const maxFileBytes = 12 * 1024 * 1024;
  static const iterations = 600000;
  static final _aad = utf8.encode(
    'kuyena-backup|1|PBKDF2-HMAC-SHA256|600000|AES-256-GCM',
  );
  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
  static bool isEncrypted(Uint8List bytes) {
    _size(bytes);
    try {
      final json = jsonDecode(utf8.decode(bytes));
      return json is Map && json['format'] == 'kuyena-backup';
    } catch (_) {
      return false;
    }
  }

  static void _size(Uint8List bytes) {
    if (bytes.length > maxFileBytes) {
      throw const BackupException('Die Sicherungsdatei ist zu groß.');
    }
  }

  static List<int> _random(int count) {
    final random = Random.secure();
    return List.generate(count, (_) => random.nextInt(256));
  }

  static void validatePassword(String password) {
    if (password.runes.length < 12 || utf8.encode(password).length > 1024) {
      throw const BackupException(
        'Wähle ein Passwort mit mindestens 12 Zeichen und höchstens 1024 UTF-8-Bytes.',
      );
    }
  }

  Future<Uint8List> encrypt(String plaintext, String password) async {
    validatePassword(password);
    if (utf8.encode(plaintext).length > BackupDocument.maxBytes) {
      throw const BackupException('Die Sicherung ist zu groß.');
    }
    final salt = _random(16), nonce = _cipher.newNonce();
    final key = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    try {
      final box = await _cipher.encrypt(
        utf8.encode(plaintext),
        secretKey: key,
        nonce: nonce,
        aad: _aad,
      );
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'kuyena-backup',
            'version': 1,
            'kdf': 'PBKDF2-HMAC-SHA256',
            'iterations': iterations,
            'cipher': 'AES-256-GCM',
            'salt': base64Encode(salt),
            'nonce': base64Encode(box.nonce),
            'ciphertext': base64Encode(box.cipherText),
            'tag': base64Encode(box.mac.bytes),
          }),
        ),
      );
    } finally {
      key.destroy();
    }
  }

  Future<String> decrypt(Uint8List bytes, String password) async {
    _size(bytes);
    if (utf8.encode(password).length > 1024) {
      throw const BackupException('Das Passwort ist zu lang.');
    }
    late List<int> salt, nonce, ciphertext, tag;
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic> ||
          json['format'] != 'kuyena-backup' ||
          json['version'] != 1 ||
          json['kdf'] != 'PBKDF2-HMAC-SHA256' ||
          json['iterations'] != iterations ||
          json['cipher'] != 'AES-256-GCM') {
        throw const FormatException();
      }
      salt = base64Decode(json['salt'] as String);
      nonce = base64Decode(json['nonce'] as String);
      tag = base64Decode(json['tag'] as String);
      ciphertext = base64Decode(json['ciphertext'] as String);
      if (salt.length != 16 ||
          nonce.length != 12 ||
          tag.length != 16 ||
          ciphertext.isEmpty ||
          ciphertext.length > BackupDocument.maxBytes) {
        throw const FormatException();
      }
    } catch (_) {
      throw const BackupException(
        'Das Sicherungsformat wird nicht unterstützt oder die Datei ist beschädigt.',
      );
    }
    final key = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    try {
      final plain = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
        secretKey: key,
        aad: _aad,
      );
      return utf8.decode(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupException(
        'Das Passwort stimmt nicht oder die Sicherung wurde verändert. Es wurden keine Daten übernommen.',
      );
    } on FormatException {
      throw const BackupException(
        'Die entschlüsselte Sicherung ist beschädigt.',
      );
    } finally {
      key.destroy();
    }
  }
}
