import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_period_repository.dart';

final class SecurePeriodStorage implements PeriodStorage {
  const SecurePeriodStorage({
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

  @override
  Future<String?> read() => storage.read(key: key);

  @override
  Future<void> write(String value) => storage.write(key: key, value: value);

  @override
  Future<void> delete() => storage.delete(key: key);
}
