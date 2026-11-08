import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<int> addEntry(String date, int categoryId, int amount) => db
      .into(db.entries)
      .insert(
        EntriesCompanion.insert(
          kind: EntryKind.expense,
          date: date,
          time: '12:00',
          categoryId: categoryId,
          amount: amount,
        ),
      );

  test('처음 만들 때 기본 카테고리가 지출 4개, 수입 4개 들어간다', () async {
    final expense = await db.watchCategories(EntryKind.expense).first;
    final income = await db.watchCategories(EntryKind.income).first;
    expect(expense.map((c) => c.name), ['식비', '교통', '카페', '쇼핑']);
    expect(income.map((c) => c.name), ['월급', '용돈', '부수입', '금융수입']);
  });

  test('한 달 내역은 그 달 것만, 최신순으로 나온다', () async {
    await addEntry('2026-10-31', 1, 1000);
    await addEntry('2026-11-01', 1, 2000);
    await addEntry('2026-11-05', 2, 3000);

    final nov = await db.watchMonthEntries('2026-11').first;
    expect(nov.map((e) => e.amount), [3000, 2000]);
  });

  test('달별 예산 저장/읽기: 방식을 바꾸면 이전 카테고리 예산은 남지 않는다', () async {
    expect((await db.getMonthBudget('2026-11')).totalBudget, 0);

    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.category,
        categoryAmounts: {1: 200000, 3: 60000},
      ),
    );
    var b = await db.getMonthBudget('2026-11');
    expect(b.mode, BudgetMode.category);
    expect(b.totalBudget, 260000);

    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.total,
        total: 1000000,
      ),
    );
    b = await db.getMonthBudget('2026-11');
    expect(b.mode, BudgetMode.total);
    expect(b.totalBudget, 1000000);
    expect(b.categoryAmounts, isEmpty);

    // 다른 달에는 영향이 없다.
    expect((await db.getMonthBudget('2026-10')).totalBudget, 0);
  });

  test('카테고리 예산만 바뀌어도 예산 스트림이 다시 알려준다', () async {
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.category,
        categoryAmounts: {1: 100000},
      ),
    );
    final updates = db.watchMonthBudget('2026-11').map((b) => b.totalBudget);
    final expectation = expectLater(updates, emitsThrough(150000));
    await db
        .into(db.monthCategoryBudgets)
        .insert(
          MonthCategoryBudgetsCompanion.insert(
            monthKey: '2026-11',
            categoryId: 2,
            amount: 50000,
          ),
        );
    await expectation;
  });

  test('기록 초기화: 내역·예산은 비우고 기본 카테고리만 다시 넣는다', () async {
    await addEntry('2026-11-01', 1, 2000);
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.total,
        total: 500000,
      ),
    );
    await (db.update(db.categories)..where((c) => c.id.equals(1))).write(
      const CategoriesCompanion(name: Value('밥')),
    );

    await db.clearRecords();

    expect(await db.select(db.entries).get(), isEmpty);
    expect((await db.getMonthBudget('2026-11')).totalBudget, 0);
    final expense = await db.watchCategories(EntryKind.expense).first;
    expect(expense.map((c) => c.name), ['식비', '교통', '카페', '쇼핑']);
    expect(await db.select(db.categories).get(), hasLength(8));
  });

  test('없는 카테고리를 가리키는 내역은 저장되지 않는다', () async {
    await expectLater(addEntry('2026-11-01', 999, 1000), throwsA(anything));
  });
}
