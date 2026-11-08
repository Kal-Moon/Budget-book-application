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
}
