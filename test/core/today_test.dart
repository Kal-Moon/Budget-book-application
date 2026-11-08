import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/core/today.dart';

import '../helpers.dart';

void main() {
  // 회귀 테스트: 이전 앱은 "오늘"을 시작 때 한 번만 계산해서,
  // 앱을 켜둔 채 월말을 넘기면 "이번 달"이 지난달로 남아 있었다.
  test('10/31 23:59 → 11/1 00:01: 오늘과 이번 달이 바뀐다', () {
    final clock = FakeClock(DateTime(2026, 10, 31, 23, 59));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(clock)],
    );
    addTearDown(container.dispose);

    expect(container.read(todayProvider), DateTime(2026, 10, 31));
    expect(container.read(currentMonthKeyProvider), '2026-10');

    clock.current = DateTime(2026, 11, 1, 0, 1);
    container.read(todayProvider.notifier).refresh();

    expect(container.read(todayProvider), DateTime(2026, 11, 1));
    expect(container.read(currentMonthKeyProvider), '2026-11');
  });

  test('같은 날 안에서는 값이 바뀌지 않는다', () {
    final clock = FakeClock(DateTime(2026, 11, 8, 9));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(clock)],
    );
    addTearDown(container.dispose);

    final before = container.read(todayProvider);
    clock.current = DateTime(2026, 11, 8, 22);
    container.read(todayProvider.notifier).refresh();
    expect(identical(container.read(todayProvider), before), isTrue);
  });
}
