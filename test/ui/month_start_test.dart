import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/period.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'pump.dart';

/// 한 달 시작일: 세부 설정에서 바꾸기, 홈·새 달 팝업·분석이 기간을 따르는지.
void main() {
  /// 처음부터 10일 시작으로 쓰고 있던 것으로 한다.
  final startOn10 = PeriodCalendar([const MonthStartChange('2026-01', 10)])
      .encode();

  Finder disabledSwitches() =>
      find.byWidgetPredicate((w) => w is Switch && w.onChanged == null);

  testWidgets('세부 설정에서 시작일을 바꾸면 확인창을 거쳐 이번 달부터 적용된다', (tester) async {
    await pumpApp(tester, clock: FakeClock(DateTime(2026, 11, 20, 10)));
    await openTab(tester, '설정');
    await tap(tester, find.text('세부 설정'));

    // 1일 시작이면 통계 맞추기 체크는 누를 수 없다.
    expect(disabledSwitches(), findsNWidgets(2));
    await tap(tester, find.text('시작일'));
    await tap(tester, find.text('10일'));

    expect(find.text('한 달 시작일을 10일로 바꿀까요?'), findsOneWidget);
    expect(find.textContaining('· 10월: 10.1 ~ 11.9 (40일)'), findsOneWidget);
    expect(find.textContaining('· 11월: 11.10 ~ 12.9'), findsOneWidget);
    expect(find.textContaining('10월 합계와 예산 초과 표시가 달라질 수 있어요'), findsOneWidget);
    await tap(tester, find.text('바꾸기'));

    expect(find.text('✓ 한 달 시작일을 10일로 바꿨어요'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.monthStartChanges'), '[["2026-11",10]]');
    expect(find.text('10일 ›'), findsOneWidget);
    expect(find.textContaining('이번 11월: 11.10 ~ 12.9.'), findsOneWidget);
    expect(disabledSwitches(), findsNothing);

    await tap(tester, find.bySemanticsLabel('월간 통계도 시작일에 맞추기'));
    expect(prefs.getBool('settings.alignMonthStats'), isTrue);
  });

  testWidgets('시작일을 고르기만 하고 확인창에서 취소하면 바뀌지 않는다', (tester) async {
    await pumpApp(tester, clock: FakeClock(DateTime(2026, 11, 20, 10)));
    await openTab(tester, '설정');
    await tap(tester, find.text('세부 설정'));
    await tap(tester, find.text('시작일'));
    await tap(tester, find.text('말일'));
    await tap(tester, find.text('취소'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.monthStartChanges'), isNull);
    expect(find.text('1일 ›'), findsOneWidget);
  });

  testWidgets('홈은 시작일 기준 기간의 지출과 날짜 범위를 보여준다', (tester) async {
    await pumpApp(
      tester,
      clock: FakeClock(DateTime(2026, 11, 20, 10)),
      settings: {'monthStartChanges': startOn10},
      setup: (db) async {
        await db.saveMonthBudget(
          const MonthBudget(
            monthKey: '2026-11',
            mode: BudgetMode.total,
            total: 100000,
          ),
        );
        await addEntry(db, date: '2026-11-09', categoryId: 1, amount: 5000);
        await addEntry(db, date: '2026-11-15', categoryId: 1, amount: 3000);
        await addEntry(db, date: '2026-11-20', categoryId: 2, amount: 7000);
      },
    );

    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('11.10 ~ 12.9'), findsOneWidget);
    // 11/9는 10월 기간이라 빠진다: 3,000 + 7,000.
    expect(find.text('90,000원'), findsOneWidget);

    // 날짜 선택 창: 달력은 1일~말일이고, "전체 보기"에는 기간 날짜를 붙인다.
    await tap(tester, find.text('2026년 11월'));
    expect(find.text('2026년 11월 전체 보기 (11.10 ~ 12.9)'), findsOneWidget);
  });

  testWidgets('시작일이 10일이면 앱을 켜 둔 채 11/9 23:59 → 11/10 00:01에 새 달 예산을 묻는다', (
    tester,
  ) async {
    final clock = FakeClock(DateTime(2026, 11, 9, 23, 59));
    await pumpApp(
      tester,
      clock: clock,
      settings: {
        'monthStartChanges': startOn10,
        'budgetPromptMonth': '2026-10',
      },
      setup: (AppDatabase db) => db.saveMonthBudget(
        const MonthBudget(
          monthKey: '2026-10',
          mode: BudgetMode.total,
          total: 500000,
        ),
      ),
    );
    expect(find.text('10월 지출'), findsOneWidget);
    expect(find.text('10.10 ~ 11.9'), findsOneWidget);

    clock.current = DateTime(2026, 11, 10, 0, 1);
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);

    expect(find.text('11월 예산을 정해주세요'), findsOneWidget);
    await tap(tester, find.text('나중에'));
    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('11.10 ~ 12.9'), findsOneWidget);
  });

  group('분석', () {
    Future<void> data(AppDatabase db) async {
      await db.saveMonthBudget(
        const MonthBudget(
          monthKey: '2026-11',
          mode: BudgetMode.category,
          categoryAmounts: {1: 5000},
        ),
      );
      // 11/5는 10월 기간(달력으로는 11월), 11/15는 11월 기간.
      await addEntry(db, date: '2026-11-05', categoryId: 1, amount: 4000);
      await addEntry(db, date: '2026-11-15', categoryId: 1, amount: 6000);
    }

    testWidgets('월간 통계를 맞추지 않으면 달력 기준이고 예산과 비교하지 않는다', (tester) async {
      await pumpApp(
        tester,
        clock: FakeClock(DateTime(2026, 11, 20, 10)),
        settings: {'monthStartChanges': startOn10},
        setup: data,
      );
      await openTab(tester, '분석');

      expect(find.text('달력 기준 · 11.1 ~ 11.30'), findsOneWidget);
      expect(find.text('예산 비교는 홈에서 볼 수 있어요'), findsOneWidget);
      expect(find.text('11월 예산 방식'), findsNothing);
      expect(find.text('10,000원'), findsWidgets);
      expect(find.text('초과'), findsNothing);
    });

    testWidgets('월간 통계를 시작일에 맞추면 기간 기준이고 예산 초과를 표시한다', (tester) async {
      await pumpApp(
        tester,
        clock: FakeClock(DateTime(2026, 11, 20, 10)),
        settings: {'monthStartChanges': startOn10, 'alignMonthStats': true},
        setup: data,
      );
      await openTab(tester, '분석');

      expect(find.text('11.10 ~ 12.9 기준'), findsOneWidget);
      expect(find.text('11월 예산 방식'), findsOneWidget);
      expect(find.text('6,000원'), findsWidgets);
      expect(find.text('초과'), findsOneWidget);
    });

    testWidgets('연간 통계 기준 표시: 맞추면 시작일 기준, 아니면 달력 기준', (tester) async {
      await pumpApp(
        tester,
        // 2027-01-05는 아직 2026년 12월 기간이다.
        clock: FakeClock(DateTime(2027, 1, 5, 10)),
        settings: {'monthStartChanges': startOn10, 'alignYearStats': true},
      );
      await openTab(tester, '분석');
      await tap(tester, find.text('연간 통계'));

      expect(find.text('2026.1.10 ~ 2027.1.9 기준'), findsOneWidget);
      expect(find.text('2026년'), findsOneWidget);
    });

    testWidgets('1일 시작이면 기준 문구를 보여주지 않는다', (tester) async {
      await pumpApp(tester, setup: data);
      await openTab(tester, '분석');
      expect(find.textContaining('기준'), findsNothing);
      expect(find.text('예산 비교는 홈에서 볼 수 있어요'), findsNothing);
    });
  });
}
