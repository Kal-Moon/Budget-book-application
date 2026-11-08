import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/core/today.dart';
import 'package:gagyebu/ui/home/home_view.dart';

import '../helpers.dart';

void main() {
  test('홈은 이번 달로 시작하고, 날짜가 바뀌면 보던 달·하루 보기가 이번 달로 돌아간다', () {
    final clock = FakeClock(DateTime(2026, 11, 8, 23, 59));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(clock)],
    );
    addTearDown(container.dispose);

    expect(container.read(homeViewProvider).monthKey, '2026-11');
    container.read(homeViewProvider.notifier).showDay('2026-09-03');
    expect(container.read(homeViewProvider).monthKey, '2026-09');
    expect(container.read(homeViewProvider).selectedDate, '2026-09-03');

    clock.current = DateTime(2026, 11, 9, 0, 1);
    container.read(todayProvider.notifier).refresh();

    final view = container.read(homeViewProvider);
    expect(view.monthKey, '2026-11');
    expect(view.selectedDate, isNull);
  });
}
