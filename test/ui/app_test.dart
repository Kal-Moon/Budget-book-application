import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pump.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('하단 탭 4개가 있고, 탭을 누르면 화면이 바뀐다', (tester) async {
    await pumpApp(tester);

    final nav = find.byType(NavigationBar);
    for (final label in ['홈', '입력', '분석', '설정']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(find.descendant(of: nav, matching: find.text('분석')));
    await settle(tester);
    expect(find.textContaining('월별 추이'), findsOneWidget);
  });

  testWidgets('홈은 이번 달 기준으로 지출과 남은 예산을 보여준다', (tester) async {
    await pumpApp(
      tester,
      setup: (db) => db.saveMonthBudget(
        const MonthBudget(
          monthKey: '2026-11',
          mode: BudgetMode.total,
          total: 500000,
        ),
      ),
    );

    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('500,000원'), findsOneWidget);
    expect(find.text('총 500,000원'), findsOneWidget);
  });
}
