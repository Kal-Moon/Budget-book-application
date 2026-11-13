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
    // 스크롤한 위치가 화면에 반영된 뒤에 누른다.
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> openInputTab(WidgetTester tester) => tap(
    tester,
    find.descendant(of: find.byType(NavigationBar), matching: find.text('입력')),
  );

  Finder field(String hint) => find.widgetWithText(TextField, hint);

  Future<void> type(WidgetTester tester, Finder f, String text) async {
    await tester.enterText(f, text);
    await settle(tester);
  }

  testWidgets('지출 입력: 카테고리 없이 저장하면 고르게 하고, 저장하면 홈에 보인다', (tester) async {
    await pumpApp(tester);
    await openInputTab(tester);

    expect(find.text('내역 입력'), findsOneWidget);
    expect(find.text('2026.11.08'), findsOneWidget, reason: '날짜 기본값은 오늘');
    await type(tester, field('0'), '12000');
    await tap(tester, find.text('저장'));
    expect(find.text('지출 카테고리 선택'), findsOneWidget);
    await tap(tester, find.text('식비'));

    await type(tester, field('예: 이마트, 쿠팡 (선택)'), '김밥천국');
    await type(tester, field('예: 라면 (선택)'), '점심');
    await tap(tester, find.text('저장'));

    expect(find.text('✓ 12,000원 저장됐어요'), findsOneWidget);
    expect(find.text('11월 지출'), findsOneWidget, reason: '홈으로 돌아옴');
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('식비 · 김밥천국'), findsOneWidget);
  });

  testWidgets('금액 없이 저장하면 안내만 하고 저장하지 않는다', (tester) async {
    final db = await pumpApp(tester);
    await openInputTab(tester);
    await tap(tester, find.text('저장'));
    expect(find.text('💰 금액을 입력해주세요'), findsOneWidget);
    final rows = await tester.runAsync(() => db.select(db.entries).get());
    expect(rows, isEmpty);
  });

  testWidgets('수입 입력: 구매처 칸이 없고 수입 카테고리만 고른다', (tester) async {
    await pumpApp(tester);
    await openInputTab(tester);

    await tap(tester, find.text('수입'));
    expect(find.text('얼마를 받았나요?'), findsOneWidget);
    expect(find.text('구매처'), findsNothing);
    await tap(tester, find.text('카테고리를 선택하세요'));
    expect(find.text('수입 카테고리 선택'), findsOneWidget);
    expect(find.text('식비'), findsNothing);
    await tap(tester, find.text('월급'));

    await type(tester, field('0'), '2000000');
    await tap(tester, find.text('저장'));
    expect(find.text('+2,000,000원'), findsWidgets);
  });

  testWidgets('수정·삭제: 홈에서 내역을 누르면 값이 채워져 있다', (tester) async {
    final db = await pumpApp(
      tester,
      setup: (db) => addEntry(
        db,
        date: '2026-11-07',
        time: '19:30',
        categoryId: 3,
        amount: 4500,
        description: '아메리카노',
        place: '스타벅스',
      ),
    );

    await tap(tester, find.text('아메리카노'));
    expect(find.text('2026.11.07'), findsOneWidget);
    expect(find.text('19:30'), findsWidgets);
    expect(find.text('☕  카페'), findsOneWidget);
    expect(find.text('4,500'), findsOneWidget);

    await type(tester, find.text('4,500'), '5000');
    await tap(tester, find.text('저장').last); // 맨 위(수정 화면)의 저장
    expect(find.text('✓ 수정됐어요'), findsOneWidget);
    expect(find.text('5,000원'), findsWidgets);

    await tap(tester, find.text('아메리카노'));
    await tap(tester, find.text('이 내역 삭제하기'));
    expect(find.text('이 내역을 삭제할까요?'), findsOneWidget);
    await tap(tester, find.text('삭제하기'));
    expect(find.text('아메리카노'), findsNothing);
    final rows = await tester.runAsync(() => db.select(db.entries).get());
    expect(rows, isEmpty);
  });

  testWidgets('예산 초과 경고: 항목별 예산을 넘으면 넘는 금액을 보여준다', (tester) async {
    await pumpApp(
      tester,
      setup: (db) async {
        await db.saveMonthBudget(
          const MonthBudget(
            monthKey: '2026-11',
            mode: BudgetMode.category,
            categoryAmounts: {1: 40000},
          ),
        );
        await addEntry(db, date: '2026-11-03', categoryId: 1, amount: 30000);
      },
    );
    await openInputTab(tester);
    await tap(tester, find.text('카테고리를 선택하세요'));
    await tap(tester, find.text('식비'));
    await type(tester, field('0'), '15000');
    expect(find.text('식비 예산을 5,000원 초과해요'), findsOneWidget);
    await type(tester, field('15,000'), '5000');
    expect(find.textContaining('초과해요'), findsNothing);
  });

  testWidgets('자동완성: 고른 카테고리 문구가 먼저, 다른 카테고리 문구도 나온다', (tester) async {
    await pumpApp(
      tester,
      setup: (db) async {
        await addEntry(
          db,
          date: '2026-11-03',
          categoryId: 1,
          amount: 1000,
          description: '라면',
        );
        await addEntry(
          db,
          date: '2026-11-05',
          categoryId: 2,
          amount: 1000,
          description: '라이딩',
        );
        await addEntry(
          db,
          kind: EntryKind.income,
          date: '2026-11-05',
          categoryId: 5,
          amount: 1000,
          description: '라디오 출연료',
        );
      },
    );
    await openInputTab(tester);
    await tap(tester, find.text('카테고리를 선택하세요'));
    await tap(tester, find.text('식비'));
    await tester.tap(field('예: 라면 (선택)'));
    await type(tester, field('예: 라면 (선택)'), '라');
    final shown = find.descendant(
      of: find.ancestor(
        of: find.byIcon(Icons.history),
        matching: find.byType(InkWell),
      ),
      matching: find.byType(Text),
    );
    expect(tester.widgetList<Text>(shown).map((t) => t.data), ['라면', '라이딩']);
    expect(find.text('라디오 출연료'), findsNothing, reason: '수입 내역');
    await tap(tester, find.text('라면').last);
    final f = tester.widget<TextField>(field('라면'));
    expect(f.controller!.text, '라면');
  });

  testWidgets('자동완성: 카테고리를 고르기 전에도, 칸을 누르기만 해도 구매처·메모를 추천한다', (tester) async {
    await pumpApp(
      tester,
      setup: (db) => addEntry(
        db,
        date: '2026-11-03',
        categoryId: 3,
        amount: 4500,
        place: '스타벅스',
        memo: '친구랑',
      ),
    );
    await openInputTab(tester);
    expect(find.text('스타벅스'), findsNothing, reason: '칸에 들어가기 전');

    await tap(tester, field('예: 이마트, 쿠팡 (선택)'));
    expect(find.text('스타벅스'), findsOneWidget);
    await tap(tester, find.text('스타벅스'));
    expect(tester.widget<TextField>(field('스타벅스')).controller!.text, '스타벅스');
    expect(find.byIcon(Icons.history), findsNothing, reason: '내역 칸으로 넘어감');

    await tap(tester, field('추가로 남기고 싶은 메모 (선택)'));
    await tap(tester, find.text('친구랑'));
    expect(tester.widget<TextField>(field('친구랑')).controller!.text, '친구랑');
  });

  testWidgets('카테고리 빠른 추가: 같은 이름은 막고, 새 이름은 추가하고 바로 고른다', (tester) async {
    await pumpApp(tester);
    await openInputTab(tester);
    await tap(tester, find.text('카테고리를 선택하세요'));

    await type(tester, field('새 카테고리 이름'), '식비');
    await tap(tester, find.text('추가'));
    expect(find.text('이미 있는 이름이에요'), findsOneWidget);

    await type(tester, field('식비'), '의료');
    await tap(tester, find.text('추가'));
    expect(find.textContaining('  의료'), findsOneWidget, reason: '바로 선택됨');
  });

  testWidgets('실수 방지를 켜면 저장 전에 한 번 더 묻는다', (tester) async {
    await pumpApp(tester, settings: {'mistapProtection': true});
    await openInputTab(tester);
    await tap(tester, find.text('카테고리를 선택하세요'));
    await tap(tester, find.text('카페'));
    await type(tester, field('0'), '3000');
    await tap(tester, find.text('저장'));
    expect(find.text('저장할까요?'), findsOneWidget);
    await tap(tester, find.text('저장하기'));
    expect(find.text('✓ 3,000원 저장됐어요'), findsOneWidget);
  });

  testWidgets('입력 탭을 다시 열면 빈 화면으로 시작한다', (tester) async {
    await pumpApp(tester);
    await openInputTab(tester);
    await type(tester, field('0'), '777');
    await tap(tester, find.text('취소'));
    expect(find.text('11월 지출'), findsOneWidget);
    await openInputTab(tester);
    expect(find.text('777'), findsNothing);
  });
}
