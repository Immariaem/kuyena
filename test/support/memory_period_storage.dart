import 'package:kuyena_tracker/periods/data/local_period_repository.dart';

class MemoryPeriodStorage implements PeriodStorage {
  MemoryPeriodStorage([this.value]);
  String? value;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('Test: Lesen fehlgeschlagen.');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('Test: Schreiben fehlgeschlagen.');
    this.value = value;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw StateError('Test: Löschen fehlgeschlagen.');
    value = null;
  }
}
