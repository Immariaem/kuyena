import 'dart:async';

/// Reentrant within one operation, serialized across independent operations.
/// Repositories and use cases share the same lock in the production app.
class DataLock {
  final Object _zoneKey = Object();
  Future<void> _pending = Future.value();
  Future<T> run<T>(Future<T> Function() operation) {
    if (Zone.current[_zoneKey] == true) return operation();
    final result = _pending.then(
      (_) => runZoned(() => exclusive(operation), zoneValues: {_zoneKey: true}),
    );
    _pending = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<T> exclusive<T>(Future<T> Function() operation) => operation();
}
