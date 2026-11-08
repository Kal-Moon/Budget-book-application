import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/categories.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<List<CategoryDraft>> expenseDrafts() async => [
    for (final c in await db.watchCategories(EntryKind.expense).first)
      CategoryDraft(id: c.id, name: c.name, icon: c.icon, color: c.color),
  ];

  test('편집한 지출 카테고리대로 저장하고, 항목별 예산을 새 id에 연결한다', () async {
    final drafts = await expenseDrafts();
    drafts.removeAt(2); // 카페 삭제
    drafts[0].name = '밥값'; // 식비 → 밥값
    drafts.add(CategoryDraft(name: '의료', icon: '💊', color: newCategoryColor));

    await db.saveOnboarding(
      drafts: drafts,
      monthKey: '2026-11',
      mode: BudgetMode.category,
      categoryAmounts: {0: 200000, 3: 50000},
    );

    final expense = await db.watchCategories(EntryKind.expense).first;
    expect(expense.map((c) => c.name), ['밥값', '교통', '쇼핑', '의료']);
    final income = await db.watchCategories(EntryKind.income).first;
    expect(income, hasLength(4), reason: '수입 카테고리는 그대로');

    final budget = await db.getMonthBudget('2026-11');
    expect(budget.mode, BudgetMode.category);
    expect(budget.totalBudget, 250000);
    expect(budget.categoryBudget(expense.last.id), 50000);
    expect(budget.categoryBudget(expense[1].id), 0);
  });

  test('총 예산 방식은 총액만 저장한다', () async {
    await db.saveOnboarding(
      drafts: await expenseDrafts(),
      monthKey: '2026-11',
      mode: BudgetMode.total,
      total: 1000000,
      categoryAmounts: {0: 99},
    );
    final budget = await db.getMonthBudget('2026-11');
    expect(budget.mode, BudgetMode.total);
    expect(budget.totalBudget, 1000000);
    expect(budget.categoryAmounts, isEmpty);
  });

  test('건너뛰기(mode 없음)는 예산을 저장하지 않는다', () async {
    await db.saveOnboarding(drafts: await expenseDrafts(), monthKey: '2026-11');
    expect((await db.getMonthBudget('2026-11')).totalBudget, 0);
  });
}
