import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/summary.dart';

import '../helpers.dart';

/// 기본 카테고리 id: 1 식비, 2 교통, 3 카페, 4 쇼핑.
void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  // 회귀 테스트: 이전 앱은 카테고리를 옮기며 삭제할 때 예산을 그냥 지워서,
  // 예산을 지켰던 과거 달이 "초과"로 바뀌었다.
  test('옮기며 삭제: 내역과 모든 달의 예산이 대상 카테고리로 합쳐져 과거 달이 초과로 바뀌지 않는다', () async {
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-10',
        mode: BudgetMode.category,
        categoryAmounts: {1: 200000, 3: 60000},
      ),
    );
    // 11월에는 식비 예산이 없고 카페 예산만 있다.
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.category,
        categoryAmounts: {3: 50000},
      ),
    );
    await addEntry(db, date: '2026-10-10', categoryId: 1, amount: 180000);
    await addEntry(db, date: '2026-10-11', categoryId: 3, amount: 50000);

    await db.deleteCategory(3, moveTo: 1);

    final oct = await db.getMonthBudget('2026-10');
    expect(oct.categoryBudget(1), 260000);
    expect(oct.totalBudget, 260000, reason: '10월 총 예산은 그대로');
    final spent = EntryTotals(await db.watchMonthEntries('2026-10').first);
    expect(spent.spentIn(1), 230000);
    expect(isOverBudget(spent.spentIn(1), oct.categoryBudget(1), 100), isFalse);

    final nov = await db.getMonthBudget('2026-11');
    expect(nov.categoryBudget(1), 50000, reason: '대상에 예산이 없던 달은 새로 생김');
    expect(nov.categoryAmounts.containsKey(3), isFalse);

    final names = (await db.watchCategories(EntryKind.expense).first).map(
      (c) => c.name,
    );
    expect(names, ['식비', '교통', '쇼핑']);
  });

  test('내역까지 삭제: 그 카테고리의 내역·예산만 사라진다', () async {
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.category,
        categoryAmounts: {1: 200000, 3: 60000},
      ),
    );
    await addEntry(db, date: '2026-11-01', categoryId: 1, amount: 1000);
    await addEntry(db, date: '2026-11-02', categoryId: 3, amount: 2000);

    expect(await db.countEntriesIn(3), 1);
    await db.deleteCategory(3);

    final left = await db.select(db.entries).get();
    expect(left.map((e) => e.categoryId), [1]);
    final budget = await db.getMonthBudget('2026-11');
    expect(budget.totalBudget, 200000);
  });

  test('수정: 이름·아이콘·색상, 카테고리 예산 하나만 바꾸기', () async {
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.category,
        categoryAmounts: {1: 200000, 2: 50000},
      ),
    );
    await db.updateCategory(1, name: ' 밥값 ', icon: '🍜', color: 0xFFE24B4A);
    await db.setCategoryBudget('2026-11', 1, 150000);

    final cat = (await db.watchCategories(EntryKind.expense).first).first;
    expect((cat.name, cat.icon, cat.color), ('밥값', '🍜', 0xFFE24B4A));
    final budget = await db.getMonthBudget('2026-11');
    expect(budget.categoryBudget(1), 150000);
    expect(budget.categoryBudget(2), 50000);
  });

  // 회귀 테스트: 이전 앱은 예산을 카테고리 **이름**으로 찾아 저장해서,
  // 같은 이름이 생기면 예산을 덮어쓰거나 엉뚱한 카테고리에 붙였다.
  test('예산은 id로 붙는다: 이름을 바꿔도 남고, 지운 카테고리와 같은 이름으로 새로 만들어도 이어받지 않는다', () async {
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.category,
        categoryAmounts: {1: 200000, 3: 60000},
      ),
    );

    await db.updateCategory(1, name: '밥값', icon: '🍚', color: 0);
    await db.deleteCategory(3);
    final newCafe = await db.addCategory(
      kind: EntryKind.expense,
      name: '카페',
      icon: '☕',
      color: 0,
    );

    final budget = await db.getMonthBudget('2026-11');
    expect(budget.categoryBudget(1), 200000, reason: '이름을 바꿔도 같은 카테고리');
    expect(budget.categoryBudget(newCafe), 0, reason: '새 "카페"는 다른 카테고리');
    expect(budget.categoryAmounts, {1: 200000});
  });
}
