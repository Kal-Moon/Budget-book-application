import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
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

  group('자동완성', () {
    List<String> desc(List<Entry> list, String q, {int? categoryId}) =>
        suggestTexts(list, (e) => e.description, q, categoryId: categoryId);

    test('포함하는 문구를 최근 것부터, 중복 없이, 같은 글자는 빼고', () {
      final list = [
        entry(1, date: '2026-11-01', description: '라면'),
        entry(2, date: '2026-11-05', description: '라떼'),
        entry(3, date: '2026-11-03', description: '라면'),
        entry(4, date: '2026-11-04', description: '김밥'),
      ];
      expect(desc(list, '라'), ['라떼', '라면']);
      expect(desc(list, '라면'), isEmpty);
    });

    test('칸이 비어 있으면 최근 문구를 최대 5개 보여준다(빈 문구는 빼고)', () {
      final list = [
        for (var i = 1; i <= 7; i++)
          entry(i, date: '2026-11-0$i', description: '내역$i'),
        entry(8, date: '2026-11-09'),
      ];
      expect(desc(list, ''), ['내역7', '내역6', '내역5', '내역4', '내역3']);
      expect(desc(list, ' '), hasLength(5));
    });

    test('다른 카테고리 문구도 나오지만, 고른 카테고리 문구가 먼저다', () {
      final list = [
        entry(1, date: '2026-11-07', categoryId: 2, description: '라이딩'),
        entry(2, date: '2026-11-01', categoryId: 1, description: '라면'),
      ];
      expect(desc(list, '라', categoryId: 1), ['라면', '라이딩']);
      expect(desc(list, '라'), ['라이딩', '라면'], reason: '카테고리 없으면 최근 순');
    });

    test('구매처·메모처럼 다른 칸에도 쓴다(영문 대소문자 무시)', () {
      final list = [
        entry(1, place: 'Starbucks', memo: '친구랑'),
        entry(2, place: '스타벅스'),
      ];
      expect(suggestTexts(list, (e) => e.place, 'star'), ['Starbucks']);
      expect(suggestTexts(list, (e) => e.memo, ''), ['친구랑']);
    });
  });
}
