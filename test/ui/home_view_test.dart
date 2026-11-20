import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/today.dart';
import 'package:gagyebu/domain/period.dart';
import 'package:gagyebu/ui/home/home_view.dart';

import '../helpers.dart';

void main() {
  test('홈은 이번 달로 시작하고, 날짜가 바뀌면 보던 달·하루 보기가 이번 달로 돌아간다', () async {
    final clock = FakeClock(DateTime(2026, 11, 8, 23, 59));
    final container = await clockContainer(clock);

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

  test('한 달 시작일이 10일이면 하루를 고를 때 그날이 속한 기간을 본다', () async {
    final container = await clockContainer(
      FakeClock(DateTime(2026, 11, 8)),
      settings: {
        'monthStartChanges': PeriodCalendar([
          const MonthStartChange('2026-01', 10),
        ]).encode(),
      },
    );

    // 11/8은 10월 기간(10.10 ~ 11.9)이다.
    expect(container.read(homeViewProvider).monthKey, '2026-10');
    container.read(homeViewProvider.notifier).showDay('2026-12-09');
    expect(container.read(homeViewProvider).monthKey, '2026-11');
    container.read(homeViewProvider.notifier).showDay('2026-12-10');
    expect(container.read(homeViewProvider).monthKey, '2026-12');
  });
}
