import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_period_repository.dart';

final class SecurePeriodStorage implements PeriodStorage {
  const SecurePeriodStorage({
    this.documentKey = key,
    this.storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
      aOptions: AndroidOptions(migrateWithBackup: true),
    ),
  });

  // Keep the original key so existing records remain accessible. The JSON
  // document itself contains its version.
  static const key = 'kuyena.period_starts.v1';
  final FlutterSecureStorage storage;
  final String documentKey;

  @override
  Future<String?> read() => storage.read(key: documentKey);

  @override
  Future<void> write(String value) =>
      storage.write(key: documentKey, value: value);

  @override
  Future<void> delete() => storage.delete(key: documentKey);
}
