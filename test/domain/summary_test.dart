import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/summary.dart';

Entry entry(
  int id, {
  EntryKind kind = EntryKind.expense,
  String date = '2026-11-08',
  String time = '12:00',
  int categoryId = 1,
  int amount = 1000,
  String description = '',
  String place = '',
  String memo = '',
}) => Entry(
  id: id,
  kind: kind,
  date: date,
  time: time,
  categoryId: categoryId,
  amount: amount,
  place: place,
  description: description,
  memo: memo,
);

Category category(int id, String name, EntryKind kind) => Category(
  id: id,
  kind: kind,
  name: name,
  icon: '🍚',
  color: 0xFF378ADD,
  sortOrder: id,
);

void main() {
  test('합계: 지출·수입·차액과 카테고리별 지출', () {
    final t = EntryTotals([
      entry(1, categoryId: 1, amount: 12000),
      entry(2, categoryId: 1, amount: 3000),
      entry(3, categoryId: 2, amount: 5000),
      entry(4, kind: EntryKind.income, categoryId: 5, amount: 30000),
    ]);
    expect(t.expense, 20000);
    expect(t.income, 30000);
    expect(t.difference, 10000);
    expect(t.spentIn(1), 15000);
    expect(t.spentIn(3), 0);
    expect(t.byCategory.containsKey(5), isFalse, reason: '수입은 지출 합계에 없음');
  });

  test('날짜별 묶음: 날짜 최신순, 같은 날은 시간 최신순, 순액은 수입 − 지출', () {
    final groups = groupByDate([
      entry(1, date: '2026-11-07', time: '09:00'),
      entry(2, date: '2026-11-08', time: '08:00', amount: 5000),
      entry(3, date: '2026-11-08', time: '20:00', amount: 2000),
      entry(4, date: '2026-11-08', kind: EntryKind.income, amount: 10000),
    ]);
    expect(groups.map((g) => g.date), ['2026-11-08', '2026-11-07']);
    expect(groups.first.entries.map((e) => e.id), [3, 4, 2]);
    expect(groups.first.net, 3000);
  });

  group('검색', () {
    final cats = {
      1: category(1, '식비', EntryKind.expense),
      5: category(5, '월급', EntryKind.income),
    };
    final all = [
      entry(1, description: '라면', place: '이마트'),
      entry(2, memo: 'Starbucks 쿠폰'),
      entry(
        3,
        kind: EntryKind.income,
        categoryId: 5,
        description: '11월 급여',
        place: '이마트',
      ),
    ];
    List<int> ids(String q) =>
        searchEntries(all, cats, q).map((e) => e.id).toList();

    test('내역·메모, 영문 대소문자 무시', () {
      expect(ids('라면'), [1]);
      expect(ids('starbucks'), [2]);
    });

    test('구매처는 지출에서만 찾는다', () {
      expect(ids('이마트'), [1]);
    });

    test('카테고리 이름으로도 찾는다', () {
      expect(ids('식비'), [1, 2]);
      expect(ids('월급'), [3]);
    });

    test('빈 검색어는 결과가 없다', () {
      expect(ids('  '), isEmpty);
    });
  });

  group('검색: 띄어쓰기·낱말', () {
    final cats = {
      1: category(1, '카페', EntryKind.expense),
      2: category(2, '식비', EntryKind.expense),
      5: category(5, '월급', EntryKind.income),
    };
    final all = [
      // 두 칸에 나눠 쓴 기록
      entry(1, place: '스타벅스', description: '아메리카노'),
      // 한 칸에 쓴 기록(내역에만 저장)
      entry(2, description: '스타벅스 아메리카노'),
      entry(3, categoryId: 2, place: 'GS25', description: '삼각김밥'),
      entry(4, place: '이마트', description: '장보기', memo: '할인 쿠폰'),
      entry(
        5,
        kind: EntryKind.income,
        categoryId: 5,
        place: '회사',
        description: '11월 급여',
      ),
    ];
    List<int> ids(String q) =>
        searchEntries(all, cats, q).map((e) => e.id).toList();

    test('띄어 쓴 검색어는 두 칸 기록과 한 칸 기록을 모두 찾는다', () {
      expect(ids('스타벅스 아메리카노'), [1, 2]);
    });

    test('붙여 쓴 검색어도 두 칸 기록과 한 칸 기록을 모두 찾는다', () {
      expect(ids('스타벅스아메리카노'), [1, 2]);
    });

    test('낱말 순서가 달라도 찾는다', () {
      expect(ids('아메리카노 스타벅스'), [1, 2]);
    });

    test('기록의 띄어쓰기와 검색어의 띄어쓰기가 달라도 찾는다', () {
      expect(ids('삼각 김밥'), [3]);
      expect(ids('벅스아메'), [1, 2]);
    });

    test('모든 낱말이 들어 있어야 찾는다', () {
      expect(ids('스타벅스 이마트'), isEmpty);
    });

    test('낱말은 서로 다른 칸에 있어도 된다(구매처·메모·카테고리)', () {
      expect(ids('이마트 쿠폰'), [4]);
      expect(ids('카페 아메리카노'), [1, 2]);
    });

    test('메모·카테고리명은 구매처·내역과 이어 붙이지 않는다', () {
      expect(ids('장보기할인'), isEmpty);
      expect(ids('카페아메리카노'), isEmpty);
    });

    test('수입은 구매처로 찾지 않는다(띄어쓰기를 무시해도)', () {
      expect(ids('회사'), isEmpty);
      expect(ids('11월급여'), [5]);
    });

    test('검색어 앞뒤·중간의 여러 빈칸은 무시한다', () {
      expect(ids('  스타벅스   아메리카노 '), [1, 2]);
    });
  });
}
