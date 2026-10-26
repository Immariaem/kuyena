import 'period.dart';

abstract interface class PeriodRepository {
  Future<List<Period>> load();
  Future<void> save(List<Period> periods);
  Future<void> clear();
}
