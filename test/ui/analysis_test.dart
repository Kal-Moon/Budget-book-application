import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/core/today.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/ui/analysis/analysis_view.dart';
import 'package:gagyebu/ui/analysis/analysis_widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';
import 'pump.dart';

/// 기준 시각은 2026-11-08. 11월: 식비 42,000 · 교통 3,500 · 카페 4,500 = 50,000.
Future<void> sampleData(AppDatabase db) async {
  await addEntry(
    db,
    date: '2026-11-08',
    categoryId: 1,
    amount: 12000,
    description: '점심',
  );
  await addEntry(
    db,
    date: '2026-11-05',
    categoryId: 1,
    amount: 30000,
    description: '장보기',
  );
  await addEntry(db, date: '2026-11-07', categoryId: 2, amount: 3500);
  await addEntry(db, date: '2026-11-08', categoryId: 3, amount: 4500);
  await addEntry(
    db,
    kind: EntryKind.income,
    date: '2026-11-01',
    categoryId: 5,
    amount: 2000000,
  );
  await addEntry(
    db,
    date: '2026-10-31',
    categoryId: 1,
    amount: 99000,
    description: '지난달 외식',
  );
  await addEntry(db, date: '2025-12-25', categoryId: 4, amount: 120000);
  await db.saveMonthBudget(
    const MonthBudget(
      monthKey: '2026-11',
      mode: BudgetMode.category,
      categoryAmounts: {1: 40000, 2: 5000},
    ),
  );
  await db.saveMonthBudget(
    const MonthBudget(
      monthKey: '2026-10',
      mode: BudgetMode.total,
      total: 50000,
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    // 스크롤한 위치가 화면에 반영된 뒤에 누른다.
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> openAnalysis(WidgetTester tester) => tap(
    tester,
    find.descendant(of: find.byType(NavigationBar), matching: find.text('분석')),
  );

  testWidgets('카테고리 비중: 금액·비율·초과 표시, 카테고리를 누르면 그 달 내역', (tester) async {
    await pumpApp(tester, setup: sampleData);
    await openAnalysis(tester);

    expect(find.text('11월 예산 방식'), findsOneWidget);
    expect(find.text('항목별로 정하기'), findsOneWidget);
    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('50,000원'), findsWidgets);
    expect(find.text('42,000원'), findsOneWidget);
    expect(find.text('84%'), findsOneWidget);
    expect(find.text('초과'), findsOneWidget, reason: '식비만 예산을 넘음');
    expect(find.textContaining('데이터를 보는 중'), findsNothing);

    await tap(tester, find.text('식비'));
    expect(find.text('11월 · 🍚 식비 내역'), findsOneWidget);
    expect(find.text('장보기'), findsOneWidget);
    expect(find.text('지난달 외식'), findsNothing);
  });

  testWidgets('수입으로 전환하면 수입 카테고리 구성을 보여주고 초과 표시는 없다', (tester) async {
    await pumpApp(tester, setup: sampleData);
    await openAnalysis(tester);
    await tap(tester, find.text('수입').last);

    expect(find.text('11월 수입'), findsOneWidget);
    expect(find.text('월급'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('초과'), findsNothing);
  });

  testWidgets('지출이 없는 달은 빈 원과 안내를 보여준다', (tester) async {
    await pumpApp(tester);
    await openAnalysis(tester);
    expect(find.text('아직 이번 달 지출이 없어요'), findsOneWidget);
    expect(find.text('아직 정하지 않음'), findsOneWidget);
  });

  testWidgets('월별 추이: 이번 달에서 끝나고, 달을 누르면 그 달 비중으로 이동한다', (tester) async {
    await pumpApp(tester, setup: sampleData);
    await openAnalysis(tester);
    await tap(tester, find.text('월별 추이'));

    expect(find.text('평균 지출'), findsOneWidget);
    expect(
      find.text('-49,000원'),
      findsOneWidget,
      reason: '전월 대비 50,000 − 99,000',
    );
    expect(find.text('99,000원'), findsWidgets, reason: '10월 합계·최고 지출월');
    expect(find.text('▼ 49,000 (-49.5%)'), findsOneWidget);

    await tap(tester, find.text('99,000원').last);
    expect(find.text('2026년 10월 데이터를 보는 중'), findsOneWidget);
    expect(find.text('10월 지출'), findsOneWidget);
    expect(find.text('총 예산으로 정하기'), findsOneWidget, reason: '10월의 방식');

    await tap(tester, find.text('이번 달로 돌아가기'));
    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.textContaining('데이터를 보는 중'), findsNothing);
  });

  testWidgets('연간 통계: 올해 합계·월평균, 해를 옮기면 그 해 데이터', (tester) async {
    await pumpApp(tester, setup: sampleData);
    await openAnalysis(tester);
    await tap(tester, find.text('연간 통계'));

    expect(find.text('2026년 총 지출'), findsOneWidget);
    expect(find.text('149,000원'), findsWidgets);
    expect(find.text('월평균 13,545원'), findsOneWidget, reason: '÷ 11개월');

    await tap(tester, find.text('식비'));
    expect(find.text('2026년 · 🍚 식비 월별 내역'), findsOneWidget);
    expect(find.text('10월'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    await tap(tester, find.byTooltip('이전 년도'));
    expect(find.text('2025년 총 지출'), findsOneWidget);
    expect(find.text('월평균 10,000원'), findsOneWidget, reason: '÷ 12개월');
    await tap(tester, find.byTooltip('이전 년도'));
    expect(find.text('2024년 지출 내역이 없어요 🙂'), findsOneWidget);
  });

  testWidgets('분석은 홈에서 보던 달과 상관없이 이번 달을 보여준다', (tester) async {
    await pumpApp(tester, setup: sampleData);
    // 홈에서 10월로 이동
    await tap(tester, find.text('2026년 11월'));
    await tap(tester, find.text('11월'));
    await tap(tester, find.text('10월'));
    await tap(tester, find.text('2026년 10월 전체 보기'));
    expect(find.text('10월 지출'), findsOneWidget);

    await openAnalysis(tester);
    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.textContaining('데이터를 보는 중'), findsNothing);
  });

  testWidgets('요약 표시를 끄면 분석의 수입·지출·차액 줄이 사라진다', (tester) async {
    await pumpApp(
      tester,
      settings: {'showAnalysisIncome': false},
      setup: sampleData,
    );
    await openAnalysis(tester);
    expect(find.text('차액'), findsNothing);
  });

  testWidgets('세부 설정에서 강조색을 바꾸면 저장된다', (tester) async {
    await pumpApp(tester, setup: sampleData);
    await tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('설정'),
      ),
    );
    await tap(tester, find.text('세부 설정'));
    expect(find.text('총 지출도 함께 강조'), findsOneWidget, reason: '항목별 방식인 달');
    await tap(tester, find.bySemanticsLabel('강조색 mint'));
    await tap(tester, find.bySemanticsLabel('총 지출도 함께 강조'));
    await tester.binding.handlePopRoute();
    await settle(tester);
    await openAnalysis(tester);
    // 총 지출 50,000 > 항목별 합계 45,000 → 가운데 금액이 민트 강조색 글자색으로.
    final total = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(DonutChart),
            matching: find.text('50,000원'),
          )
          .first,
    );
    expect(total.style!.color, const Color(0xFF085041));
  });

  test('분석이 보는 달·해는 날짜가 바뀌면 이번 달로 돌아간다', () {
    final clock = FakeClock(DateTime(2026, 12, 31, 23, 59));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(clock)],
    );
    addTearDown(container.dispose);

    container.read(analysisViewProvider.notifier).showMonth('2026-09');
    container.read(analysisViewProvider.notifier).moveYear(-2);
    clock.current = DateTime(2027, 1, 1, 0, 1);
    container.read(todayProvider.notifier).refresh();

    final view = container.read(analysisViewProvider);
    expect(view.monthKey, '2027-01');
    expect(view.year, 2027);
  });
}
