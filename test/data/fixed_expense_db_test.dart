import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<FixedExpense> only() async =>
      (await db.watchFixedExpenses().first).single;

  test('새로 만들면 오늘 이후 처음 오는 그날부터, 그날이 되면 내역으로 넣는다', () async {
    await db.saveFixedExpense(
      name: '월세',
      categoryId: 1,
      amount: 500000,
      day: 25,
      place: '집주인',
      today: '2026-11-20',
    );
    expect((await only()).nextDate, '2026-11-25');
    expect(await db.applyFixedExpenses('2026-11-24'), 0);

    expect(await db.applyFixedExpenses('2026-11-25'), 1);
    expect(
      await db.applyFixedExpenses('2026-11-25'),
      0,
      reason: '같은 날 두 번 넣지 않음',
    );
    final e = (await db.select(db.entries).get()).single;
    expect(
      (e.kind, e.date, e.categoryId, e.amount, e.description, e.place),
      (EntryKind.expense, '2026-11-25', 1, 500000, '월세', '집주인'),
    );
    expect((await only()).nextDate, '2026-12-25');
  });

  test('오래 안 열면 빠진 달을 모두 넣는다', () async {
    await db.saveFixedExpense(
      name: '통신비',
      categoryId: 2,
      amount: 55000,
      day: 31,
      today: '2026-11-20',
    );
    expect(await db.applyFixedExpenses('2027-02-28'), 4);
    final dates = [for (final e in await db.select(db.entries).get()) e.date];
    expect(dates, ['2026-11-30', '2026-12-31', '2027-01-31', '2027-02-28']);
  });

  test('끄면 넣지 않고, 다시 켜면 지난 달은 채우지 않는다', () async {
    await db.saveFixedExpense(
      name: '구독',
      categoryId: 4,
      amount: 9900,
      day: 5,
      today: '2026-11-01',
    );
    final id = (await only()).id;
    await db.setFixedExpenseActive(id, false, today: '2026-11-02');
    expect(await db.applyFixedExpenses('2027-01-10'), 0);
    await db.setFixedExpenseActive(id, true, today: '2027-01-10');
    expect((await only()).nextDate, '2027-02-05');
    expect(await db.applyFixedExpenses('2027-01-10'), 0);
  });

  test('카테고리를 옮기며 지우면 고정 지출도 옮기고, 그냥 지우면 함께 지운다', () async {
    await db.saveFixedExpense(
      name: '월세',
      categoryId: 4,
      amount: 1,
      day: 1,
      today: '2026-11-20',
    );
    await db.deleteCategory(4, moveTo: 1);
    expect((await only()).categoryId, 1);
    await db.deleteCategory(1);
    expect(await db.watchFixedExpenses().first, isEmpty);
  });

  test('내역 데이터 초기화에서 고정 지출도 지운다', () async {
    await db.saveFixedExpense(
      name: '월세',
      categoryId: 1,
      amount: 1,
      day: 1,
      today: '2026-11-20',
    );
    await db.clearRecords();
    expect(await db.watchFixedExpenses().first, isEmpty);
  });
}
