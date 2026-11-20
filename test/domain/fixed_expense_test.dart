import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/fixed_expense.dart';

void main() {
  test('없는 날은 그 달 말일', () {
    expect(fixedDateIn(2026, 2, 31), '2026-02-28');
    expect(fixedDateIn(2028, 2, 30), '2028-02-29');
    expect(fixedDateIn(2026, 11, 31), '2026-11-30');
    expect(nextFixedDate('2026-02-28', 31), '2026-03-31', reason: '원래 날로 돌아감');
    expect(nextFixedDate('2026-12-25', 25), '2027-01-25');
  });

  test('처음 입력일: 오늘이 그날이면 오늘, 지났으면 다음 달', () {
    expect(firstFixedDateFrom('2026-11-20', 25), '2026-11-25');
    expect(firstFixedDateFrom('2026-11-20', 20), '2026-11-20');
    expect(firstFixedDateFrom('2026-11-20', 5), '2026-12-05');
  });

  test('앱을 오래 안 열면 빠진 달을 모두 채운다', () {
    final r = dueFixedDates(next: '2026-09-25', day: 25, today: '2026-11-25');
    expect(r.dates, ['2026-09-25', '2026-10-25', '2026-11-25']);
    expect(r.next, '2026-12-25');
    expect(
      dueFixedDates(next: '2026-12-25', day: 25, today: '2026-11-30').dates,
      isEmpty,
    );
  });

  test('날짜를 바꾸거나 다시 켤 때: 이미 입력한 달은 건너뛰고, 지난 날은 채우지 않는다', () {
    // 11월 5일분은 이미 입력(다음 12/5) → 25일로 바꾸면 12/25
    expect(
      resumeFixedDate(storedNext: '2026-12-05', day: 25, today: '2026-11-20'),
      '2026-12-25',
    );
    // 아직 11월분 전(다음 11/25) → 22일로 바꾸면 11/22
    expect(
      resumeFixedDate(storedNext: '2026-11-25', day: 22, today: '2026-11-20'),
      '2026-11-22',
    );
    // 8월부터 멈췄다가 11/20에 다시 켬 → 지난 달은 채우지 않고 11/25부터
    expect(
      resumeFixedDate(storedNext: '2026-08-25', day: 25, today: '2026-11-20'),
      '2026-11-25',
    );
  });
}
