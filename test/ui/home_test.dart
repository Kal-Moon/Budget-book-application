import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';
import 'pump.dart';

/// 기준 시각은 2026-11-08(일) 10:00.
Future<void> sampleData(AppDatabase db) async {
  await addEntry(
    db,
    date: '2026-11-08',
    time: '12:30',
    categoryId: 1,
    amount: 12000,
    description: '점심',
    place: '김밥천국',
  );
  await addEntry(
    db,
    date: '2026-11-08',
    time: '09:10',
    categoryId: 3,
    amount: 4500,
    place: '스타벅스',
  );
  await addEntry(
    db,
    date: '2026-11-07',
    categoryId: 2,
    amount: 3500,
    description: '버스',
  );
  await addEntry(
    db,
    date: '2026-11-05',
    categoryId: 1,
    amount: 30000,
    description: '장보기',
  );
  await addEntry(
    db,
    kind: EntryKind.income,
    date: '2026-11-01',
    categoryId: 5,
    amount: 2000000,
    description: '11월 급여',
  );
  await addEntry(
    db,
    date: '2026-10-31',
    categoryId: 1,
    amount: 99000,
    description: '지난달 외식',
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  testWidgets('총 예산 방식: 요약·수입 줄·카테고리 칩(금액·비율)·날짜별 목록', (tester) async {
    await pumpApp(
      tester,
      setup: (db) async {
        await sampleData(db);
        await db.saveMonthBudget(
          const MonthBudget(
            monthKey: '2026-11',
            mode: BudgetMode.total,
            total: 100000,
          ),
        );
      },
    );

    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('50,000원'), findsWidgets);
    expect(find.text('사용 50%'), findsOneWidget);
    expect(find.text('수입'), findsWidgets);
    expect(find.text('2,000,000원'), findsWidgets);
    expect(find.text('+1,950,000원'), findsOneWidget);

    expect(find.text('42,000 · 84%'), findsOneWidget, reason: '식비 칩');
    expect(find.text('오늘 · 11월 8일 일'), findsOneWidget);
    expect(find.text('어제 · 11월 7일 토'), findsOneWidget);
    expect(find.text('지난달 외식'), findsNothing, reason: '10월 내역은 안 보임');
    // 내역이 비면 카테고리 이름을 흐리게 보여준다.
    expect(find.text('카페 · 스타벅스'), findsOneWidget);
    expect(find.text('카페'), findsWidgets);
  });

  testWidgets('항목별 방식: 넘은 카테고리는 "예산 초과", 총액을 넘으면 "○원 초과"', (tester) async {
    await pumpApp(
      tester,
      setup: (db) async {
        await sampleData(db);
        await db.saveMonthBudget(
          const MonthBudget(
            monthKey: '2026-11',
            mode: BudgetMode.category,
            categoryAmounts: {1: 40000, 2: 5000},
          ),
        );
      },
    );

    expect(find.text('42,000 / 40,000'), findsOneWidget);
    expect(find.text('3,500 / 5,000'), findsOneWidget);
    expect(find.text('식비 · 김밥천국 · 예산 초과'), findsOneWidget);
    expect(find.text('5,000원 초과'), findsOneWidget, reason: '50,000 − 45,000');
  });

  testWidgets('수입 필터: 수입만 보이고 카테고리 필터가 수입 카테고리로 바뀐다', (tester) async {
    await pumpApp(tester, setup: sampleData);

    await tap(tester, find.text('수입').last);
    expect(find.text('11월 급여'), findsOneWidget);
    expect(find.text('점심'), findsNothing);
    expect(find.text('💼 월급'), findsOneWidget);

    await tap(tester, find.text('지출').last);
    await tap(tester, find.text('🚌 교통').last); // 아래쪽 카테고리 필터 칩
    expect(find.text('버스'), findsOneWidget);
    expect(find.text('점심'), findsNothing);
  });

  testWidgets('날짜 선택: 하루만 보기 → 그 달 전체 보기', (tester) async {
    await pumpApp(tester, setup: sampleData);

    await tap(tester, find.text('2026년 11월'));
    expect(find.text('날짜 선택'), findsOneWidget);
    await tap(tester, find.text('5'));

    expect(find.text('11월 5일 목만 보는 중'), findsOneWidget);
    expect(find.text('선택한 날 지출'), findsOneWidget);
    expect(find.text('장보기'), findsOneWidget);
    expect(find.text('점심'), findsNothing);

    await tap(tester, find.text('11월 전체 보기'));
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('2026년 11월'), findsOneWidget);
  });

  testWidgets('다른 달로 이동하면 그 달 이름으로 표시된다', (tester) async {
    await pumpApp(tester, setup: sampleData);

    await tap(tester, find.text('2026년 11월'));
    await tap(tester, find.text('11월'));
    await tap(tester, find.text('10월'));
    await tap(tester, find.text('2026년 10월 전체 보기'));

    expect(find.text('10월 지출'), findsOneWidget);
    expect(find.text('지난달 외식'), findsOneWidget);
    expect(
      find.textContaining('예산이 설정되지 않았어요'),
      findsNothing,
      reason: '배너는 이번 달만',
    );
  });

  testWidgets('검색: 전체 기간에서 구매처로 찾고, 취소하면 돌아온다', (tester) async {
    await pumpApp(tester, setup: sampleData);

    await tap(tester, find.byTooltip('검색'));
    await tester.enterText(find.byType(TextField), '스타벅스');
    await settle(tester);
    expect(find.text('2026년 11월 8일 일'), findsOneWidget);
    expect(find.text('카페 · 스타벅스'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '외식');
    await settle(tester);
    expect(find.text('지난달 외식'), findsOneWidget, reason: '지난 달도 찾음');

    await tap(tester, find.text('취소'));
    expect(find.text('11월 지출'), findsOneWidget);
  });

  testWidgets('비율 막대를 누르면 분석 탭으로 간다', (tester) async {
    await pumpApp(tester, setup: sampleData);
    await tap(tester, find.bySemanticsLabel('카테고리별 지출 비율'));
    expect(find.textContaining('월별 추이'), findsOneWidget);
  });
}
