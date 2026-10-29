@TestOn('browser')
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/data/storage/platform_data_lock.dart';

void main() {
  test(
    'Browser-origin locks coordinate separate instances and allow nested operations',
    () async {
      final first = createDataLock(),
          second = createDataLock(),
          events = <String>[],
          gate = Completer<void>(),
          started = Completer<void>();
      final a = first.run(() async {
        events.add('first');
        started.complete();
        await gate.future;
        await first.run(() async => events.add('nested'));
        events.add('released');
      });
      await started.future;
      final b = second.run(() async => events.add('second'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(events, ['first']);
      gate.complete();
      await Future.wait([a, b]);
      expect(events, ['first', 'nested', 'released', 'second']);
      await expectLater(
        first.run(() async => throw StateError('test')),
        throwsStateError,
      );
      expect(await second.run(() async => 42), 42);
    },
  );
}
