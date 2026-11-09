import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/summary.dart';

import 'summary_test.dart' show entry;

void main() {
  group('budgetWarning', () {
    String? warn({
      int spentBefore = 30000,
      int amount = 15000,
      int budget = 40000,
      int threshold = 100,
    }) => budgetWarning(
      label: '식비',
      spentBefore: spentBefore,
      amount: amount,
      budget: budget,
      thresholdPercent: threshold,
    );

    test('예산을 넘으면 넘는 금액을 알려준다', () {
      expect(warn(), '식비 예산을 5,000원 초과해요');
    });

    test('임계값에는 닿았지만 아직 넘지 않았으면 비율을 알려준다(음수 초과 금액 없음)', () {
      expect(warn(amount: 4000, threshold: 80), '식비 예산의 85%를 쓰게 돼요');
    });

    test('넘지 않거나, 예산이 없거나, 금액이 없으면 경고 없음', () {
      expect(warn(amount: 5000), isNull);
      expect(warn(budget: 0), isNull);
      expect(warn(amount: 0), isNull);
    });
  });

  test('자동완성: 포함하는 내역을 최근 것부터, 중복 없이, 같은 글자는 빼고', () {
    final list = [
      entry(1, date: '2026-11-01', description: '라면'),
      entry(2, date: '2026-11-05', description: '라떼'),
      entry(3, date: '2026-11-03', description: '라면'),
      entry(4, date: '2026-11-04', description: '김밥'),
    ];
    expect(suggestDescriptions(list, '라'), ['라떼', '라면']);
    expect(suggestDescriptions(list, '라면'), isEmpty);
    expect(suggestDescriptions(list, ' '), isEmpty);
  });
}
