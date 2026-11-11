import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/analysis.dart';
import 'package:gagyebu/domain/budget.dart';

import 'summary_test.dart' show entry;

void main() {
  final entries = [
    entry(1, date: '2026-11-03', categoryId: 1, amount: 30000),
    entry(2, date: '2026-10-10', categoryId: 1, amount: 50000),
    entry(3, date: '2026-10-11', categoryId: 3, amount: 10000),
    entry(4, date: '2026-08-01', categoryId: 2, amount: 20000),
    entry(5, date: '2025-12-25', categoryId: 1, amount: 120000),
    entry(6, date: '2026-11-01', kind: EntryKind.income, amount: 999999),
  ];

  test('월별 합계: 끝 달에서 거슬러 올라가며, 내역 없는 달은 0, 수입은 제외', () {
    final months = monthlyExpenseTotals(entries, '2026-11', 4);
    expect(months.map((m) => m.monthKey), [
      '2026-08',
      '2026-09',
      '2026-10',
      '2026-11',
    ]);
    expect(months.map((m) => m.total), [20000, 0, 60000, 30000]);
    expect(months.last.label, '26.11');
  });

  test('월별 합계는 해를 넘어간다', () {
    final months = monthlyExpenseTotals(entries, '2026-01', 3);
    expect(months.map((m) => m.monthKey), ['2025-11', '2025-12', '2026-01']);
    expect(months[1].total, 120000);
  });

  test('추이 요약: 평균, 전월 대비, 최고 지출월', () {
    final stats = TrendStats(monthlyExpenseTotals(entries, '2026-11', 4));
    expect(stats.average, 27500);
    expect(stats.difference, -30000);
    expect(stats.highest!.monthKey, '2026-10');
    expect(percentChange(60000, 30000), '-50.0%');
    expect(percentChange(0, 30000), '-', reason: '0에서의 증감률은 계산 불가');
  });

  group('연간 통계', () {
    test('올해는 지금까지 지난 달 수로 평균을 낸다', () {
      final stats = YearStats(entries, 2026, DateTime(2026, 11, 8));
      expect(stats.total, 110000);
      expect(stats.monthlyAverage, 10000, reason: '110,000 ÷ 11개월');
      expect(stats.categoryTotal(1), 80000);
      expect(stats.byCategory[1]![9], 50000, reason: '10월');
      expect(stats.byCategory[1]![10], 30000, reason: '11월');
    });

    test('지난 해는 12로 나눈다', () {
      final stats = YearStats(entries, 2025, DateTime(2026, 11, 8));
      expect(stats.total, 120000);
      expect(stats.monthlyAverage, 10000);
    });

    test('내역이 없는 해는 0', () {
      final stats = YearStats(entries, 2027, DateTime(2026, 11, 8));
      expect(stats.total, 0);
      expect(stats.monthlyAverage, 0);
    });
  });

  group('달 전체 강조', () {
    bool highlighted(MonthBudget b, int spent, {bool also = false}) =>
        highlightMonthTotal(
          budget: b,
          spent: spent,
          thresholdPercent: 100,
          alsoInCategoryMode: also,
        );
    const total = MonthBudget(
      monthKey: '2026-11',
      mode: BudgetMode.total,
      total: 100,
    );
    const byCategory = MonthBudget(
      monthKey: '2026-11',
      mode: BudgetMode.category,
      categoryAmounts: {1: 100},
    );

    test('총 예산 방식은 넘으면 항상 강조', () {
      expect(highlighted(total, 100), isTrue);
      expect(highlighted(total, 99), isFalse);
    });

    test('항목별 방식은 설정을 켰을 때만 강조', () {
      expect(highlighted(byCategory, 150), isFalse);
      expect(highlighted(byCategory, 150, also: true), isTrue);
    });
  });

  test('알 수 없는 강조색 키는 기본(빨강)으로', () {
    expect(highlightColorOf('mint').key, 'mint');
    expect(highlightColorOf('???').key, 'red');
    expect(highlightColors, hasLength(12));
  });
}
