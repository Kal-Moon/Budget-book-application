import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  EntriesCompanion row(int amount) => EntriesCompanion(
    kind: const Value(EntryKind.expense),
    date: const Value('2026-11-08'),
    time: const Value('12:00'),
    categoryId: const Value(1),
    amount: Value(amount),
  );

  test('내역 추가 → 수정 → 삭제', () async {
    await db.saveEntry(row(1000));
    final added = (await db.select(db.entries).get()).single;
    expect(added.amount, 1000);

    await db.saveEntry(row(2500), id: added.id);
    final updated = (await db.select(db.entries).get()).single;
    expect(updated.id, added.id);
    expect(updated.amount, 2500);

    await db.deleteEntry(added.id);
    expect(await db.select(db.entries).get(), isEmpty);
  });

  test('카테고리 추가는 맨 뒤에 붙는다', () async {
    final id = await db.addCategory(
      kind: EntryKind.expense,
      name: ' 의료 ',
      icon: '💊',
      color: 0xFF888780,
    );
    final expense = await db.watchCategories(EntryKind.expense).first;
    expect(expense.last.id, id);
    expect(expense.last.name, '의료');
  });
}
