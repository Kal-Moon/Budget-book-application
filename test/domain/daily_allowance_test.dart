import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/daily_allowance.dart';

void main() {
  DailyAllowance? calc({
    int budget = 300000,
    int before = 0,
    int today = 0,
    String date = '2026-11-21',
    String end = '2026-11-30',
  }) => dailyAllowanceOf(
    budget: budget,
    spentBeforeToday: before,
    spentToday: today,
    today: date,
    periodEnd: end,
  );

  test('어제까지 남은 예산 ÷ 오늘 포함 남은 날, 원 단위 버림', () {
    final a = calc(before: 100000, today: 5000)!;
    expect(a.daysLeft, 10);
    expect(a.perDay, 20000);
    expect(a.leftToday, 15000);
    expect(calc(budget: 100000, end: '2026-11-23')!.perDay, 33333);
  });

  test('오늘 하루 금액보다 더 쓰면 음수', () {
    expect(calc(before: 100000, today: 25000)!.leftToday, -5000);
  });

  test('말일에는 남은 예산 전부, 한 달 시작일이 달라도 기간 끝까지 센다', () {
    expect(calc(before: 280000, date: '2026-11-30')!.perDay, 20000);
    expect(calc(date: '2026-11-21', end: '2026-12-09')!.daysLeft, 19);
  });

  test('예산이 0원이거나 이미 넘었으면 보여주지 않는다', () {
    expect(calc(budget: 0), isNull);
    expect(calc(before: 290000, today: 20000), isNull);
    expect(calc(before: 300000), isNotNull, reason: '딱 다 쓴 것은 0원');
  });
}
