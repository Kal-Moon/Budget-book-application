import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/period.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('기록이 없으면 달력과 같다', () {
    final cal = PeriodCalendar();

    test('1일~말일, 2월과 해 넘김', () {
      expect(cal.isCalendar, isTrue);
      expect(
        cal.rangeOf('2026-02'),
        const DateRange('2026-02-01', '2026-02-28'),
      );
      expect(
        cal.rangeOf('2026-12'),
        const DateRange('2026-12-01', '2026-12-31'),
      );
      expect(cal.keyOf(d(2026, 11, 1)), '2026-11');
      expect(cal.keyOf(d(2026, 10, 31)), '2026-10');
      expect(cal.isPlainMonth('2026-11'), isTrue);
      expect(cal.yearRange(2026), const DateRange('2026-01-01', '2026-12-31'));
    });
  });

  group('10일 시작', () {
    final cal = PeriodCalendar([const MonthStartChange('2000-01', 10)]);

    test('기간 이름은 시작하는 달', () {
      expect(
        cal.rangeOf('2026-11'),
        const DateRange('2026-11-10', '2026-12-09'),
      );
      expect(cal.keyOf(d(2026, 11, 9)), '2026-10');
      expect(cal.keyOf(d(2026, 11, 10)), '2026-11');
      expect(cal.keyOf(d(2026, 12, 9)), '2026-11');
      expect(cal.rangeLabel('2026-11'), '11.10 ~ 12.9');
      expect(cal.isPlainMonth('2026-11'), isFalse);
    });

    test('해를 넘는 기간과 연간 범위', () {
      expect(cal.keyOf(d(2027, 1, 9)), '2026-12');
      expect(
        cal.rangeOf('2026-12'),
        const DateRange('2026-12-10', '2027-01-09'),
      );
      expect(cal.yearRange(2026), const DateRange('2026-01-10', '2027-01-09'));
      expect(cal.yearRangeLabel(2026), '2026.1.10 ~ 2027.1.9');
    });
  });

  test('말일 시작: 그 달의 마지막 날부터 다음 달 마지막 날의 전날까지', () {
    final cal = PeriodCalendar([const MonthStartChange('2000-01', lastDay)]);
    expect(cal.rangeOf('2026-11'), const DateRange('2026-11-30', '2026-12-30'));
    expect(cal.rangeOf('2027-01'), const DateRange('2027-01-31', '2027-02-27'));
    expect(cal.rangeOf('2027-02'), const DateRange('2027-02-28', '2027-03-30'));
    expect(cal.keyOf(d(2026, 11, 29)), '2026-10');
    expect(cal.keyOf(d(2026, 11, 30)), '2026-11');
  });

  group('시작일을 바꾸면 이번 달부터 바로 적용하고, 그 전 날짜는 전월로 간다', () {
    test('1일 → 10일: 11월은 10일부터, 11/1~11/9는 10월로', () {
      final cal = PeriodCalendar().withStartDay(d(2026, 11, 20), 10);
      expect(cal.changes, [const MonthStartChange('2026-11', 10)]);
      expect(cal.chosenDay, 10);
      expect(
        cal.rangeOf('2026-09'),
        const DateRange('2026-09-01', '2026-09-30'),
      );
      expect(
        cal.rangeOf('2026-10'),
        const DateRange('2026-10-01', '2026-11-09'),
      );
      expect(
        cal.rangeOf('2026-11'),
        const DateRange('2026-11-10', '2026-12-09'),
      );
      expect(cal.keyOf(d(2026, 11, 5)), '2026-10');
      expect(cal.keyOf(d(2026, 11, 20)), '2026-11');
      expect(cal.yearRange(2026), const DateRange('2026-01-01', '2027-01-09'));
    });

    test('오늘이 새 시작일 전이면 오늘은 전월 기간이다', () {
      final cal = PeriodCalendar().withStartDay(d(2026, 11, 5), 10);
      expect(cal.keyOf(d(2026, 11, 5)), '2026-10');
      expect(
        cal.rangeOf('2026-10'),
        const DateRange('2026-10-01', '2026-11-09'),
      );
    });

    test('10일 → 1일: 11월은 1일부터, 전월(10월)은 10월 말일에 끝난다', () {
      final ten = PeriodCalendar([const MonthStartChange('2026-01', 10)]);
      final cal = ten.withStartDay(d(2026, 11, 20), 1);
      expect(
        cal.rangeOf('2026-09'),
        const DateRange('2026-09-10', '2026-10-09'),
      );
      expect(
        cal.rangeOf('2026-10'),
        const DateRange('2026-10-10', '2026-10-31'),
      );
      expect(
        cal.rangeOf('2026-11'),
        const DateRange('2026-11-01', '2026-11-30'),
      );
      // 10일 시작일 때 10월 기간이던 11/5가 이제 11월이다.
      expect(cal.keyOf(d(2026, 11, 5)), '2026-11');
    });

    test('28일 → 1일: 전월(10월)은 10.28 ~ 10.31로 줄어든다', () {
      final late = PeriodCalendar([const MonthStartChange('2026-01', 28)]);
      expect(late.keyOf(d(2026, 11, 20)), '2026-10');
      final cal = late.withStartDay(d(2026, 11, 20), 1);
      expect(
        cal.rangeOf('2026-10'),
        const DateRange('2026-10-28', '2026-10-31'),
      );
      expect(cal.keyOf(d(2026, 11, 20)), '2026-11');
    });

    test('모든 날짜가 정확히 한 기간에 들어간다(끊기거나 겹치지 않음)', () {
      final cal = PeriodCalendar()
          .withStartDay(d(2026, 3, 15), 25)
          .withStartDay(d(2026, 6, 2), lastDay)
          .withStartDay(d(2026, 9, 10), 3);
      var date = d(2026, 1, 1);
      var key = cal.keyOf(date);
      while (date.isBefore(d(2027, 3, 1))) {
        final k = cal.keyOf(date);
        expect(cal.rangeOf(k).contains(_key(date)), isTrue, reason: '$date');
        // 기간 이름은 한 달씩 차례로 이어진다.
        if (k != key) {
          expect(cal.startOf(k), date);
          expect(k.compareTo(key), greaterThan(0));
          key = k;
        }
        date = DateTime(date.year, date.month, date.day + 1);
      }
    });

    test('같은 달에 다시 바꾸면 마지막 값만 남고, 되돌리면 기록이 사라진다', () {
      final today = d(2026, 11, 20);
      final cal = PeriodCalendar()
          .withStartDay(today, 10)
          .withStartDay(d(2026, 11, 25), 15);
      expect(cal.changes, [const MonthStartChange('2026-11', 15)]);
      final back = cal.withStartDay(today, 1);
      expect(back.changes, isEmpty);
      expect(back.isCalendar, isTrue);
    });
  });

  test('저장 문자열로 오가고, 잘못된 값은 버린다', () {
    final cal = PeriodCalendar()
        .withStartDay(DateTime(2026, 11, 20), 10)
        .withStartDay(DateTime(2027, 2, 1), lastDay);
    expect(PeriodCalendar.decode(cal.encode()).changes, cal.changes);
    expect(PeriodCalendar().encode(), '');
    expect(PeriodCalendar.decode('').changes, isEmpty);
    expect(PeriodCalendar.decode('not json').changes, isEmpty);
    expect(
      PeriodCalendar.decode('[["2026-13",10],["2026-12",31],["2026-12",5]]')
          .changes,
      [const MonthStartChange('2026-12', 5)],
    );
  });

  test('시작일 표시', () {
    expect(monthStartDayLabel(1), '1일');
    expect(monthStartDayLabel(lastDay), '말일');
    expect(monthStartDays.length, 29);
  });
}

String _key(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
