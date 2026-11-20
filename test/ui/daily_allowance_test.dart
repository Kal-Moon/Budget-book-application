import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';

import '../helpers.dart';
import 'pump.dart';

/// 기준 시각 2026-11-08. 11월 예산 300,000원, 어제까지 10,000원, 오늘 5,000원.
/// 남은 날 23일(11.8 ~ 11.30) → 하루 290,000 ÷ 23 = 12,608원.
Future<void> data(AppDatabase db) async {
  await db.saveMonthBudget(
    const MonthBudget(
      monthKey: '2026-11',
      mode: BudgetMode.total,
      total: 300000,
    ),
  );
  await addEntry(db, date: '2026-11-03', categoryId: 1, amount: 10000);
  await addEntry(db, date: '2026-11-08', categoryId: 3, amount: 5000);
}

void main() {
  testWidgets('기본은 보이지 않는다', (tester) async {
    await pumpApp(tester, setup: data);
    expect(find.text('오늘 쓸 수 있는 돈'), findsNothing);
    expect(find.text('하루에 쓸 수 있는 돈'), findsNothing);
  });

  testWidgets('오늘 남은 돈: 하루 금액에서 오늘 쓴 돈을 뺀다', (tester) async {
    await pumpApp(
      tester,
      settings: {'dailyAllowance': 'leftToday'},
      setup: data,
    );
    expect(find.text('오늘 쓸 수 있는 돈'), findsOneWidget);
    expect(find.text('7,608원'), findsOneWidget);
    expect(find.text('남은 23일 기준'), findsOneWidget);
  });

  testWidgets('하루 기준 금액: 오늘 쓴 돈과 상관없이 그대로', (tester) async {
    await pumpApp(tester, settings: {'dailyAllowance': 'perDay'}, setup: data);
    expect(find.text('하루에 쓸 수 있는 돈'), findsOneWidget);
    expect(find.text('12,608원'), findsOneWidget);
    expect(find.text('오늘 5,000원 씀 · 남은 23일'), findsOneWidget);
  });

  testWidgets('세부 설정에서 켜고 끈다', (tester) async {
    await pumpApp(tester, setup: data);
    await openTab(tester, '설정');
    await tap(tester, find.text('세부 설정'));
    await tap(tester, find.text('오늘 남은 돈'));
    expect(find.textContaining('쓸수록 줄어들어요'), findsOneWidget);
    await back(tester);
    await openTab(tester, '홈');
    expect(find.text('7,608원'), findsOneWidget);
  });

  testWidgets('예산을 정하지 않은 달에는 보이지 않는다', (tester) async {
    await pumpApp(
      tester,
      settings: {'dailyAllowance': 'leftToday'},
      setup: (db) => addEntry(db, date: '2026-11-08', categoryId: 1, amount: 1),
    );
    expect(find.text('오늘 쓸 수 있는 돈'), findsNothing);
  });
}
