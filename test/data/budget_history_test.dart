import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('정하지 않은 달과 0원으로 정한 달을 구분한다', () async {
    expect((await db.getMonthBudget('2026-11')).isSet, isFalse);
    await db.saveMonthBudget(
      const MonthBudget(monthKey: '2026-11', mode: BudgetMode.total),
    );
    final b = await db.getMonthBudget('2026-11');
    expect(b.isSet, isTrue);
    expect(b.totalBudget, 0);
  });

  test('이어받을 예산은 앞선 달 중 가장 최근 것(건너뛴 달이 있어도)', () async {
    expect(await db.latestBudgetBefore('2026-11'), isNull);
    await db.saveMonthBudget(
      const MonthBudget(monthKey: '2026-07', mode: BudgetMode.total, total: 1),
    );
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-09',
        mode: BudgetMode.category,
        categoryAmounts: {1: 300},
      ),
    );
    await db.saveMonthBudget(
      const MonthBudget(monthKey: '2026-12', mode: BudgetMode.total, total: 9),
    );

    final prev = await db.latestBudgetBefore('2026-11');
    expect(prev!.monthKey, '2026-09');

    final copy = copyBudgetTo('2026-11', prev);
    await db.saveMonthBudget(copy);
    final nov = await db.getMonthBudget('2026-11');
    expect(nov.mode, BudgetMode.category);
    expect(nov.categoryAmounts, {1: 300});
  });
}
