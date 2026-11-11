import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';

import '../helpers.dart';

/// CLAUDE.md 5장 "과거 버그와 교훈"의 회귀 테스트 중 DB에 관한 것.
void main() {
  // 회귀: 빈 카테고리 목록을 "데이터 없음"으로 착각해 기본 카테고리가 되살아났다.
  // 기본 카테고리는 처음 만들 때만 넣고, 다시 열 때는 DB에 있는 그대로 둔다.
  test('앱을 다시 열어도 지우거나 바꾼 기본 카테고리가 되살아나지 않는다', () async {
    final dir = await Directory.systemTemp.createTemp('gagyebu_reopen');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    AppDatabase open() => AppDatabase(
      DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
    );

    final first = open();
    // 지출은 식비만 남기고 이름을 바꾸고, 수입은 월급만 남긴다.
    await first.updateCategory(1, name: '밥값', icon: '🍜', color: 0xFFE24B4A);
    for (final id in [2, 3, 4, 6, 7, 8]) {
      await first.deleteCategory(id);
    }
    await first.close();

    final second = open();
    addTearDown(second.close);
    final expense = await second.watchCategories(EntryKind.expense).first;
    final income = await second.watchCategories(EntryKind.income).first;
    expect(expense.map((c) => c.name), ['밥값']);
    expect(income.map((c) => c.name), ['월급']);
  });

  // 회귀: 예산을 카테고리 "이름"으로 찾아 저장해서, 이름이 바뀌거나 겹치면 예산이
  // 사라지거나 덮어써졌다. 예산은 항상 카테고리 id에 붙는다.
  test('카테고리 이름을 바꿔도 그 카테고리의 예산은 그대로다', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.category,
        categoryAmounts: {1: 200000, 3: 60000},
      ),
    );

    // 식비 ↔ 카페 이름을 맞바꿔도 예산은 id를 따라간다.
    await db.updateCategory(1, name: '임시', icon: '🍚', color: 0xFFE24B4A);
    await db.updateCategory(3, name: '식비', icon: '☕', color: 0xFFE24B4A);
    await db.updateCategory(1, name: '카페', icon: '🍚', color: 0xFFE24B4A);

    final budget = await db.getMonthBudget('2026-11');
    expect(budget.categoryBudget(1), 200000);
    expect(budget.categoryBudget(3), 60000);
    expect(budget.totalBudget, 260000);
  });
}
