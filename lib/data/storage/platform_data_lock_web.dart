import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'data_lock.dart';

@JS('navigator.locks')
external JSObject? get _locks;
DataLock createDataLock() => _BrowserDataLock();

final class _BrowserDataLock extends DataLock {
  @override
  Future<T> exclusive<T>(Future<T> Function() operation) async {
    if (_locks == null) {
      throw UnsupportedError(
        'Dieser Browser unterstützt den sicheren gemeinsamen Datenzugriff nicht. Bitte verwende einen aktuellen Browser über HTTPS oder localhost.',
      );
    }
    final result = Completer<T>();
    final callback = Zone.current.bindUnaryCallback((JSAny? _) {
      return (() async {
        try {
          result.complete(await operation());
        } catch (e, s) {
          result.completeError(e, s);
        }
        return null;
      })().toJS;
    }).toJS;
    // One origin-wide exclusive lock covers the complete read/modify/write.
    final request = web.window.navigator.locks.request(
      'kuyena-local-data-v1',
      callback,
    );
    // Attach both listeners before awaiting to avoid an unhandled Dart error.
    final value = result.future;
    unawaited(
      request.toDart.catchError((Object e, StackTrace s) {
        if (!result.isCompleted) result.completeError(e, s);
        return null;
      }),
    );
    return value;
  }
}
