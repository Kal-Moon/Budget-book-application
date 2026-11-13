import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'pump.dart';

/// 기준 시각은 2026-11-08. 10월 예산만 있으면 "새 달" 상황이 된다.
Future<void> octoberBudget(AppDatabase db) => db.saveMonthBudget(
  const MonthBudget(
    monthKey: '2026-10',
    mode: BudgetMode.category,
    categoryAmounts: {1: 200000, 3: 60000},
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    // 스크롤한 위치가 화면에 반영된 뒤에 누른다.
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> openTab(WidgetTester tester, String label) => tap(
    tester,
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  group('예산 설정', () {
    testWidgets('총 예산을 정하면 홈과 설정에 반영된다', (tester) async {
      await pumpApp(tester);
      expect(find.text('예산이 설정되지 않았어요'), findsOneWidget);
      await tap(tester, find.text('지금 설정하기'));
      expect(find.text('2026년 11월 예산을 설정해요 (오늘 기준 이번 달)'), findsOneWidget);

      await tap(tester, find.text('총 예산으로 정하기'));
      await tester.enterText(find.byType(TextField), '800000');
      await settle(tester);
      await tap(tester, find.text('저장하고 적용하기'));

      expect(find.text('✓ 예산이 저장됐어요'), findsOneWidget);
      expect(find.text('총 800,000원'), findsOneWidget);
      expect(find.text('예산이 설정되지 않았어요'), findsNothing);
      await openTab(tester, '설정');
      expect(find.text('총 예산으로 정하기 ›'), findsOneWidget);
    });

    testWidgets('항목별로 바꾸면 카테고리마다 입력하고, 다시 열면 금액이 채워져 있다', (tester) async {
      final db = await pumpApp(tester);
      await openTab(tester, '설정');
      expect(find.text('아직 정하지 않음 ›'), findsOneWidget);
      await tap(tester, find.text('예산 설정 바꾸기'));
      await tap(tester, find.text('항목별로 정하기'));

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      await tester.enterText(fields.at(0), '200000');
      await tester.enterText(fields.at(2), '60000');
      await settle(tester);
      expect(find.text('260,000원'), findsOneWidget, reason: '합계');
      await tap(tester, find.text('저장하고 적용하기'));

      final budget = await tester.runAsync(() => db.getMonthBudget('2026-11'));
      expect(budget!.mode, BudgetMode.category);
      expect(budget.categoryBudget(1), 200000);
      expect(budget.categoryBudget(3), 60000);

      await tap(tester, find.text('예산 설정 바꾸기'));
      await tap(tester, find.text('항목별로 정하기').last);
      expect(find.text('200,000'), findsOneWidget);
    });
  });

  group('새 달 예산', () {
    testWidgets('팝업에서 "그대로 쓰기"를 고르면 지난달 예산이 이번 달로 복사된다', (tester) async {
      final db = await pumpApp(tester, setup: octoberBudget);
      expect(find.text('11월 예산을 정해주세요'), findsOneWidget);
      expect(find.text('10월 예산: 항목별로 정하기 · 총 260,000원'), findsOneWidget);

      await tap(tester, find.text('10월 예산 그대로 쓰기'));
      expect(find.text('10월 예산을 이어서 적용했어요'), findsOneWidget);
      final nov = await tester.runAsync(() => db.getMonthBudget('2026-11'));
      expect(nov!.isSet, isTrue);
      expect(nov.mode, BudgetMode.category);
      expect(nov.categoryAmounts, {1: 200000, 3: 60000});
      expect(find.text('총 260,000원'), findsOneWidget);
    });

    testWidgets('"나중에"를 고르면 배너만 남고, 이번 달에는 다시 묻지 않도록 기록한다', (tester) async {
      final db = await pumpApp(tester, setup: octoberBudget);
      await tap(tester, find.text('나중에'));

      expect(find.text('예산이 설정되지 않았어요'), findsOneWidget);
      final nov = await tester.runAsync(() => db.getMonthBudget('2026-11'));
      expect(nov!.isSet, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.budgetPromptMonth'), '2026-11');
    });

    testWidgets('이미 물어본 달에는 팝업이 뜨지 않는다', (tester) async {
      await pumpApp(
        tester,
        settings: {'budgetPromptMonth': '2026-11'},
        setup: octoberBudget,
      );
      expect(find.text('11월 예산을 정해주세요'), findsNothing);
      expect(find.text('예산이 설정되지 않았어요'), findsOneWidget);
    });

    testWidgets('"새로 정하기"는 지난달 금액이 채워진 예산 설정을 연다', (tester) async {
      await pumpApp(tester, setup: octoberBudget);
      await tap(tester, find.text('새로 정하기'));
      expect(find.text('예산 설정'), findsOneWidget);
      await tap(tester, find.text('항목별로 정하기'));
      expect(find.text('200,000'), findsOneWidget);
      expect(find.text('60,000'), findsOneWidget);
    });

    testWidgets('자동 적용이 켜져 있으면 묻지 않고 복사한다', (tester) async {
      final db = await pumpApp(
        tester,
        settings: {'autoCopyBudget': true},
        setup: octoberBudget,
      );
      expect(find.text('11월 예산을 정해주세요'), findsNothing);
      expect(find.text('10월 예산을 이어서 적용했어요'), findsOneWidget);
      final nov = await tester.runAsync(() => db.getMonthBudget('2026-11'));
      expect(nov!.totalBudget, 260000);
    });

    testWidgets('이어받을 지난 예산이 없으면 묻지 않는다', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('예산을 정해주세요'), findsNothing);
    });
  });

  group('설정 항목', () {
    testWidgets('홈의 수입·지출 요약을 끌 수 있다', (tester) async {
      await pumpApp(tester);
      expect(find.text('차액'), findsOneWidget);
      await openTab(tester, '설정');
      await tap(tester, find.bySemanticsLabel('홈 화면에 표시'));
      await openTab(tester, '홈');
      expect(find.text('차액'), findsNothing);
    });

    testWidgets('자동 적용을 끄면 "다시 물어볼게요"라고 알려준다', (tester) async {
      await pumpApp(tester, settings: {'autoCopyBudget': true});
      await openTab(tester, '설정');
      await tap(tester, find.bySemanticsLabel('지난달 예산 자동 적용'));
      expect(find.text('다음 달엔 다시 물어볼게요'), findsOneWidget);
    });

    testWidgets('세부 설정: 글자 크기와 초과 알림 기준이 저장된다', (tester) async {
      await pumpApp(tester);
      await openTab(tester, '설정');
      await tap(tester, find.text('세부 설정'));
      await tap(tester, find.text('크게'));
      await tap(tester, find.text('80%'));
      expect(find.text('예산의 80%에 도달하면 미리 알려줘요'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.fontSize'), 'large');
      expect(prefs.getInt('settings.budgetThreshold'), 80);
      final scale = MediaQuery.textScalerOf(tester.element(find.text('세부 설정')))
          .scale(16);
      expect(scale, 18);
    });
  });

  group('뒤로가기', () {
    testWidgets('다른 탭에서는 홈으로 간다', (tester) async {
      await pumpApp(tester);
      await openTab(tester, '분석');
      await back(tester);
      expect(find.text('11월 지출'), findsOneWidget);
    });

    testWidgets('종료 확인을 켜면 홈에서 한 번 물어본다', (tester) async {
      await pumpApp(tester, settings: {'exitConfirm': true});
      await back(tester);
      expect(find.text('앱을 종료할까요?'), findsOneWidget);
      await tap(tester, find.text('취소'));
      expect(find.text('11월 지출'), findsOneWidget);
    });
  });

  group('데이터 초기화', () {
    Future<AppDatabase> pumpWithData(WidgetTester tester) => pumpApp(
      tester,
      settings: {'fontSize': 'large', 'budgetThreshold': 80},
      setup: (db) async {
        await addEntry(db, date: '2026-11-07', categoryId: 3, amount: 4500);
        await db.updateCategory(1, name: '밥값', icon: '🍜', color: 0xFFE24B4A);
        await db.saveMonthBudget(
          const MonthBudget(
            monthKey: '2026-11',
            mode: BudgetMode.total,
            total: 500000,
          ),
        );
      },
    );

    testWidgets('내역 데이터 초기화: 기록은 지우고 설정은 남기며 온보딩부터 다시 시작한다', (tester) async {
      final db = await pumpWithData(tester);
      await openTab(tester, '설정');
      await tap(tester, find.text('데이터 초기화'));
      expect(find.text('무엇을 초기화할까요?'), findsOneWidget);
      await tap(tester, find.text('내역 데이터 초기화'));
      expect(find.text('내역 데이터를 초기화할까요?'), findsOneWidget);
      await tap(tester, find.text('초기화하기'));

      expect(find.text('가계부에 오신 걸 환영해요'), findsOneWidget);
      final entries = await tester.runAsync(() => db.select(db.entries).get());
      expect(entries, isEmpty);
      final budget = await tester.runAsync(() => db.getMonthBudget('2026-11'));
      expect(budget!.isSet, isFalse);
      final cats = await tester.runAsync(
        () => db.watchCategories(EntryKind.expense).first,
      );
      expect(cats!.map((c) => c.name), ['식비', '교통', '카페', '쇼핑']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.fontSize'), 'large');
      expect(prefs.getInt('settings.budgetThreshold'), 80);
      expect(prefs.getBool('settings.onboardingDone'), isFalse);
    });

    testWidgets('앱 전체 초기화: 설정까지 지운다', (tester) async {
      final db = await pumpWithData(tester);
      await openTab(tester, '설정');
      await tap(tester, find.text('데이터 초기화'));
      await tap(tester, find.text('앱 전체 초기화'));
      expect(find.text('앱 전체를 초기화할까요?'), findsOneWidget);
      await tap(tester, find.text('초기화하기'));

      expect(find.text('가계부에 오신 걸 환영해요'), findsOneWidget);
      final entries = await tester.runAsync(() => db.select(db.entries).get());
      expect(entries, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    testWidgets('확인창에서 취소하면 아무것도 지우지 않는다', (tester) async {
      final db = await pumpWithData(tester);
      await openTab(tester, '설정');
      await tap(tester, find.text('데이터 초기화'));
      await tap(tester, find.text('앱 전체 초기화'));
      await tap(tester, find.text('취소'));
      final entries = await tester.runAsync(() => db.select(db.entries).get());
      expect(entries, hasLength(1));
    });
  });
}
