import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';
import 'pump.dart';

/// 회귀: 이전 앱은 날짜를 시작 때 한 번만 계산해서, 앱을 켜둔 채 자정·월말을
/// 넘기면 "오늘"과 "이번 달"이 틀어졌다. 앱 화면 단위로 10/31 23:59 → 11/1 00:01을
/// 확인한다(값 계산은 test/core/today_test.dart).
void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<FakeClock> pumpOnOctober31(WidgetTester tester) async {
    final clock = FakeClock(DateTime(2026, 10, 31, 23, 59));
    await pumpApp(
      tester,
      clock: clock,
      // 10월 예산은 정해져 있고, 10월에는 이미 물어봤다.
      settings: {'budgetPromptMonth': '2026-10'},
      setup: (db) async {
        await db.saveMonthBudget(
          const MonthBudget(
            monthKey: '2026-10',
            mode: BudgetMode.total,
            total: 500000,
          ),
        );
        await addEntry(db, date: '2026-10-31', categoryId: 1, amount: 12000);
      },
    );
    expect(find.text('10월 지출'), findsOneWidget);
    expect(find.text('11월 예산을 정해주세요'), findsNothing);
    return clock;
  }

  testWidgets('켜둔 채 자정을 넘기면 이번 달이 바뀌고 새 달 예산을 묻는다', (tester) async {
    final clock = await pumpOnOctober31(tester);

    clock.current = DateTime(2026, 11, 1, 0, 1);
    // 자정 타이머(다음 자정 + 1초)가 울리도록 가짜 시간을 흘려보낸다.
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);

    expect(find.text('11월 예산을 정해주세요'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await settle(tester);
    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('10월 지출'), findsNothing);
    expect(find.text('예산이 설정되지 않았어요'), findsOneWidget);
  });

  testWidgets('백그라운드에 있다가 다음 달에 돌아오면 이번 달로 다시 그린다', (tester) async {
    final clock = await pumpOnOctober31(tester);

    // 1분이 안 돼서 잠금과는 상관없이, 날짜만 바뀐 채로 돌아온다.
    for (final s in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    clock.current = DateTime(2026, 11, 1, 0, 1);
    for (final s in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await settle(tester);

    expect(find.text('11월 예산을 정해주세요'), findsOneWidget);
    await tester.tap(find.text('10월 예산 그대로 쓰기'));
    await settle(tester);
    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('총 500,000원'), findsOneWidget);
  });
}
