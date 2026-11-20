import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/ui/theme.dart';

import '../helpers.dart';
import 'pump.dart';

Future<void> data(AppDatabase db) async {
  await db.saveMonthBudget(
    const MonthBudget(
      monthKey: '2026-11',
      mode: BudgetMode.category,
      categoryAmounts: {1: 20000, 3: 100000},
    ),
  );
  await addEntry(db, date: '2026-11-08', categoryId: 1, amount: 25000);
  await addEntry(db, date: '2026-11-07', categoryId: 3, amount: 4500);
}

Brightness brightnessOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(NavigationBar))).brightness;

void main() {
  testWidgets('"어둡게"면 어두운 색으로 모든 탭이 그려진다', (tester) async {
    await pumpApp(tester, settings: {'theme': 'dark'}, setup: data);
    expect(brightnessOf(tester), Brightness.dark);
    final c = tester.element(find.byType(NavigationBar)).colors;
    expect(c.surface0, const AppColors.dark().surface0);
    for (final tab in ['입력', '분석', '설정', '홈']) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('기본은 폰 설정을 따른다', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    expect(brightnessOf(tester), Brightness.dark);
  });

  testWidgets('세부 설정에서 "밝게"를 고르면 폰이 다크 모드여도 밝게', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    await openTab(tester, '설정');
    await tap(tester, find.text('세부 설정'));
    await tap(tester, find.text('밝게'));
    await back(tester);
    expect(brightnessOf(tester), Brightness.light);
  });
}
