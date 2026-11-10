import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';
import 'pump.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> openManage(WidgetTester tester) async {
    await tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('설정'),
      ),
    );
    expect(find.text('지출 4개 · 수입 4개 ›'), findsOneWidget);
    await tap(tester, find.text('카테고리 관리'));
  }

  Finder nameField() => find.widgetWithText(TextField, '이름');

  testWidgets('이름 바꾸기: 같은 이름은 저장할 수 없고, 바꾸면 목록에 반영된다', (tester) async {
    await pumpApp(tester);
    await openManage(tester);
    await tap(tester, find.text('카페'));
    expect(find.text('카테고리 수정'), findsOneWidget);

    await tester.enterText(nameField(), '식비');
    await settle(tester);
    expect(find.text('이미 있는 이름이에요'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '저장'))
          .onPressed,
      isNull,
    );

    await tester.enterText(nameField(), '커피');
    await settle(tester);
    await tap(tester, find.widgetWithText(FilledButton, '저장'));
    expect(find.text('커피'), findsOneWidget);
    expect(find.text('카페'), findsNothing);
  });

  testWidgets('수입 탭: 수입 카테고리가 보이고 추가하면 수정 창이 열린다', (tester) async {
    final db = await pumpApp(tester);
    await openManage(tester);
    await tap(tester, find.text('수입'));
    expect(find.text('월급'), findsOneWidget);
    expect(find.text('식비'), findsNothing);

    await tap(tester, find.text('카테고리 추가'));
    expect(find.text('카테고리 수정'), findsOneWidget);
    await tester.enterText(nameField(), '보너스');
    await settle(tester);
    await tap(tester, find.widgetWithText(FilledButton, '저장'));
    expect(find.text('보너스'), findsOneWidget);
    final income = await tester.runAsync(
      () => db.watchCategories(EntryKind.income).first,
    );
    expect(income!.map((c) => c.name), contains('보너스'));
  });

  testWidgets('항목별 예산인 달에는 예산을 보여주고 고칠 수 있다', (tester) async {
    final db = await pumpApp(
      tester,
      setup: (db) => db.saveMonthBudget(
        const MonthBudget(
          monthKey: '2026-11',
          mode: BudgetMode.category,
          categoryAmounts: {1: 200000},
        ),
      ),
    );
    await openManage(tester);
    expect(find.text('200,000원'), findsOneWidget);
    await tap(tester, find.text('식비'));
    expect(find.text('11월 예산'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '200,000'), '150000');
    await settle(tester);
    await tap(tester, find.widgetWithText(FilledButton, '저장'));
    expect(find.text('150,000원'), findsOneWidget);
    final budget = await tester.runAsync(() => db.getMonthBudget('2026-11'));
    expect(budget!.categoryBudget(1), 150000);
  });

  testWidgets('내역이 있는 카테고리 삭제: 옮길 곳을 고르고 확인하면 내역이 옮겨진다', (tester) async {
    final db = await pumpApp(
      tester,
      setup: (db) =>
          addEntry(db, date: '2026-11-07', categoryId: 3, amount: 4500),
    );
    await openManage(tester);
    await tap(tester, find.text('카페'));
    await tap(tester, find.text('이 카테고리 삭제하기'));

    expect(find.text("'카페' 삭제"), findsOneWidget);
    await tap(tester, find.text('식비(으)로 옮기기'));
    expect(find.text("'식비'(으)로 옮길까요?"), findsOneWidget);
    await tap(tester, find.text('옮기고 삭제'));

    expect(find.text('카페'), findsNothing);
    final rows = await tester.runAsync(() => db.select(db.entries).get());
    expect(rows!.single.categoryId, 1);
  });

  testWidgets('내역이 없는 카테고리는 확인 한 번으로 삭제, 마지막 1개는 삭제할 수 없다', (tester) async {
    await pumpApp(tester);
    await openManage(tester);
    for (final name in ['교통', '카페', '쇼핑']) {
      await tap(tester, find.text(name));
      await tap(tester, find.text('이 카테고리 삭제하기'));
      expect(find.text('카테고리를 삭제할까요?'), findsOneWidget);
      await tap(tester, find.text('삭제하기'));
      expect(find.text(name), findsNothing);
    }
    await tap(tester, find.text('식비'));
    expect(find.text('카테고리는 최소 1개 필요해요'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '이 카테고리 삭제하기'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('입력 화면의 카테고리 선택 창에서 카테고리 관리로 갈 수 있다', (tester) async {
    await pumpApp(tester);
    await tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('입력'),
      ),
    );
    await tap(tester, find.text('수입'));
    await tap(tester, find.text('카테고리를 선택하세요'));
    await tap(tester, find.text('카테고리 관리 ›'));
    expect(find.text('카테고리 관리'), findsOneWidget);
    expect(find.text('월급'), findsOneWidget, reason: '수입 탭으로 열림');
  });
}
