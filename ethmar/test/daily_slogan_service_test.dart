import 'dart:math';

import 'package:ethmar/services/daily_slogan_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Random that counts how many picks were made.
class _CountingRandom implements Random {
  _CountingRandom([int seed = 1]) : _inner = Random(seed);
  final Random _inner;
  int picks = 0;

  @override
  int nextInt(int max) {
    picks++;
    return _inner.nextInt(max);
  }

  @override
  bool nextBool() => _inner.nextBool();

  @override
  double nextDouble() => _inner.nextDouble();
}

void main() {
  late DateTime now;
  late _CountingRandom random;
  late ValueNotifier<int?> notifier;

  DailySloganService service() =>
      DailySloganService(clock: () => now, random: random, notifier: notifier);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 17, 9);
    random = _CountingRandom();
    notifier = ValueNotifier(null);
  });

  test('keeps the same slogan for the whole day, even after a restart',
      () async {
    final first = await service().refresh();
    now = DateTime(2026, 10, 17, 23, 59);
    // A fresh service is like reopening the app.
    final later = await service().refresh();
    expect(later, first);
    expect(notifier.value, first);
  });

  test('never repeats the previous slogan on the next day', () async {
    var previous = await service().refresh();
    for (var day = 18; day <= 40; day++) {
      now = DateTime(2026, 10, day, 8);
      final next = await service().refresh();
      expect(next, isNot(previous));
      expect(next, inInclusiveRange(0, sloganCount - 1));
      previous = next;
    }
  });

  test('uses the stored index, not the text', () async {
    SharedPreferences.setMockInitialValues({
      'daily_slogan_index': 2,
      'daily_slogan_date': '2026-10-17',
    });
    expect(await service().refresh(), 2);
    expect(random.picks, 0);
  });

  test('replaces invalid stored data with a valid pick', () async {
    SharedPreferences.setMockInitialValues({
      'daily_slogan_index': 7,
      'daily_slogan_date': '2026-10-17',
    });
    final index = await service().refresh();
    expect(index, inInclusiveRange(0, sloganCount - 1));
  });

  test('calls at the same time share one pick and one save', () async {
    final s = service();
    final results = await Future.wait([s.refresh(), s.refresh(), s.refresh()]);
    expect(results.toSet().length, 1);
    expect(random.picks, 1);

    // Same day again: answered from memory, no new pick.
    await s.refresh();
    expect(random.picks, 1);
  });

  test('local date format', () {
    expect(DailySloganService.localDate(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
