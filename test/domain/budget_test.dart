import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/budget.dart';

void main() {
  group('isOverBudget', () {
    test('예산이 0원이면 얼마를 써도 초과가 아니다', () {
      expect(isOverBudget(50000, 0, 100), isFalse);
    });

    test('임계값 100%: 예산과 같아지는 순간부터 초과', () {
      expect(isOverBudget(99999, 100000, 100), isFalse);
      expect(isOverBudget(100000, 100000, 100), isTrue);
    });

    test('임계값 80%: 예산의 80%에 도달하면 초과', () {
      expect(isOverBudget(79999, 100000, 80), isFalse);
      expect(isOverBudget(80000, 100000, 80), isTrue);
    });
  });

  group('MonthBudget', () {
    test('총 예산 방식: 총액을 쓰고 카테고리 예산은 0', () {
      const b = MonthBudget(
        monthKey: '2026-10',
        mode: BudgetMode.total,
        total: 1000000,
        categoryAmounts: {1: 200000},
      );
      expect(b.totalBudget, 1000000);
      expect(b.categoryBudget(1), 0);
    });

    test('항목별 방식: 총 예산은 카테고리 예산의 합', () {
      const b = MonthBudget(
        monthKey: '2026-10',
        mode: BudgetMode.category,
        categoryAmounts: {1: 200000, 3: 60000},
      );
      expect(b.totalBudget, 260000);
      expect(b.categoryBudget(3), 60000);
      expect(b.categoryBudget(99), 0);
    });

    test('예산을 정하지 않은 달은 0원', () {
      const b = MonthBudget.empty('2026-11');
      expect(b.totalBudget, 0);
    });
  });
}
