import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';
import 'pump.dart';

/// 회귀 테스트: 이전 앱은 날짜를 앱을 켤 때 한 번만 계산해서, 앱을 켜 둔 채
/// 자정·월말이 지나면 "오늘"과 "이번 달"이 틀어졌다.
/// 여기서는 앱을 켜 둔 상태로 10/31 23:59 → 11/1 00:01을 지나 본다.
void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> octoberSetup(AppDatabase db) async {
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-10',
        mode: BudgetMode.total,
        total: 500000,
      ),
    );
    await addEntry(db, date: '2026-10-31', categoryId: 1, amount: 12000);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> openTab(WidgetTester tester, String label) => tap(
    tester,
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );

  /// 앱을 켜 둔 채 [to]까지 시간이 흐른다(자정 타이머가 깨어날 만큼 가짜 시간도 흘린다).
  Future<void> passTime(
    WidgetTester tester,
    FakeClock clock,
    DateTime to,
  ) async {
    final gap = to.difference(clock.current);
    clock.current = to;
    await tester.pump(gap);
    await settle(tester);
  }

  testWidgets('켜 둔 채 자정을 넘어 달이 바뀌면 홈이 11월이 되고 새 달 예산을 묻는다', (tester) async {
    final clock = FakeClock(DateTime(2026, 10, 31, 23, 59));
    await pumpApp(tester, clock: clock, setup: octoberSetup);
    expect(find.text('10월 지출'), findsOneWidget);
    expect(find.text('11월 예산을 정해주세요'), findsNothing);

    await passTime(tester, clock, DateTime(2026, 11, 1, 0, 1));

    expect(find.text('11월 예산을 정해주세요'), findsOneWidget);
    expect(find.text('10월 예산: 총 예산으로 정하기 · 총 500,000원'), findsOneWidget);
    await tap(tester, find.text('나중에'));
    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('10월 지출'), findsNothing);
    expect(find.text('예산이 설정되지 않았어요'), findsOneWidget);
  });

  testWidgets('다음 달에 앱으로 돌아오면 이번 달로 바뀌고, 자동 적용이면 지난달 예산을 이어 쓴다', (
    tester,
  ) async {
    final clock = FakeClock(DateTime(2026, 10, 31, 22));
    final db = await pumpApp(
      tester,
      clock: clock,
      settings: {'autoCopyBudget': true},
      setup: octoberSetup,
    );
    expect(find.text('10월 지출'), findsOneWidget);

    // 백그라운드에서는 타이머가 돌지 않을 수 있다. 돌아올 때 날짜를 다시 확인한다.
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    clock.current = DateTime(2026, 11, 1, 9);
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await settle(tester);

    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('10월 예산을 이어서 적용했어요'), findsOneWidget);
    final nov = await tester.runAsync(() => db.getMonthBudget('2026-11'));
    expect(nov!.isSet, isTrue);
    expect(nov.totalBudget, 500000);
  });

  testWidgets('자정이 지난 뒤 입력 탭을 열면 날짜 기본값이 새 날짜다', (tester) async {
    final clock = FakeClock(DateTime(2026, 10, 31, 23, 59));
    await pumpApp(tester, clock: clock, setup: octoberSetup);
    await openTab(tester, '입력');
    expect(find.text('2026.10.31'), findsOneWidget);
    await openTab(tester, '홈');

    await passTime(tester, clock, DateTime(2026, 11, 1, 0, 1));
    await tap(tester, find.text('나중에'));
    await openTab(tester, '입력');
    expect(find.text('2026.11.01'), findsOneWidget);
    expect(find.text('2026.10.31'), findsNothing);
  });
}
