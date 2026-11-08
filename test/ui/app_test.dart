import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/data/providers.dart';
import 'package:gagyebu/data/settings.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/main.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// DB 스트림이 값을 내놓을 때까지 실제 시간을 조금 흘려보낸 뒤 화면을 그린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> pumpApp(WidgetTester tester, {MonthBudget? budget}) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '가계부',
      packageName: 'com.mybudgetapp.gagyebu',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final prefs = await SharedPreferences.getInstance();
    final db = memoryDatabase();
    addTearDown(db.close);
    // drift는 실제 비동기 I/O를 쓰므로 가짜 시간 밖(runAsync)에서 실행한다.
    if (budget != null) await tester.runAsync(() => db.saveMonthBudget(budget));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 8, 10))),
        ],
        child: const GagyebuApp(),
      ),
    );
    await settle(tester);
  }

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
      budget: const MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.total,
        total: 500000,
      ),
    );

    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('500,000원'), findsOneWidget);
    expect(find.text('총 500,000원'), findsOneWidget);
  });
}
