import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/dates.dart';

void main() {
  test('날짜 키 형식', () {
    final t = DateTime(2026, 3, 7, 9, 5);
    expect(monthKeyOf(t), '2026-03');
    expect(dateKeyOf(t), '2026-03-07');
    expect(timeKeyOf(t), '09:05');
  });

  test('달 이동은 연도를 넘어간다', () {
    expect(shiftMonthKey('2026-01', -1), '2025-12');
    expect(shiftMonthKey('2026-12', 1), '2027-01');
    expect(shiftMonthKey('2026-10', -5), '2026-05');
  });

  test('월말 23:59에서 다음 자정까지 1분', () {
    expect(
      untilNextMidnight(DateTime(2026, 10, 31, 23, 59)),
      const Duration(minutes: 1),
    );
  });

  test('원 단위 표시', () {
    expect(formatWon(0), '0원');
    expect(formatWon(1234567), '1,234,567원');
  });
}
