import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pump.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settle(tester);
  }

  testWidgets('처음 실행하면 온보딩이 나오고, 총 예산으로 끝까지 가면 홈에 반영된다', (tester) async {
    final db = await pumpApp(tester, onboardingDone: false);

    expect(find.text('가계부에 오신 걸 환영해요'), findsOneWidget);
    await tapText(tester, '시작하기');

    expect(find.text('예산을 어떻게 정할까요?'), findsOneWidget);
    await tapText(tester, '다음');

    expect(find.text('카테고리를 확인해주세요'), findsOneWidget);
    await tapText(tester, '다음');

    expect(find.text('총 예산을 정해주세요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1200000');
    await settle(tester);
    expect(find.text('1,200,000'), findsOneWidget, reason: '세 자리마다 쉼표');
    await tapText(tester, '다음');

    expect(find.text('준비 완료!'), findsOneWidget);
    expect(find.text('1,200,000원'), findsOneWidget);
    await tapText(tester, '가계부 시작하기');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('총 1,200,000원'), findsOneWidget);
    final budget = await tester.runAsync(() => db.getMonthBudget('2026-11'));
    expect(budget!.mode, BudgetMode.total);
  });

  testWidgets('금액 칸은 빈 칸으로 시작한다(미리 채운 금액 없음)', (tester) async {
    await pumpApp(tester, onboardingDone: false);
    await tapText(tester, '시작하기');
    await tapText(tester, '항목별로 정하기');
    await tapText(tester, '다음');
    await tapText(tester, '다음');

    expect(find.text('카테고리별 예산을 정해주세요'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(4));
    for (final f in fields) {
      expect(f.controller!.text, isEmpty);
    }
  });

  testWidgets('카테고리 이름이 비거나 겹치면 다음으로 갈 수 없다', (tester) async {
    await pumpApp(tester, onboardingDone: false);
    await tapText(tester, '시작하기');
    await tapText(tester, '다음');

    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, '');
    await settle(tester);
    expect(find.text('이름을 입력해주세요'), findsOneWidget);
    FilledButton next() => tester.widget(find.byType(FilledButton));
    expect(next().onPressed, isNull);

    await tester.enterText(nameField, '교통');
    await settle(tester);
    expect(find.text('이미 있는 이름이에요'), findsNWidgets(2));
    expect(next().onPressed, isNull);

    await tester.enterText(nameField, '외식');
    await settle(tester);
    expect(next().onPressed, isNotNull);
  });

  testWidgets('마지막 카테고리는 지울 수 없다', (tester) async {
    await pumpApp(tester, onboardingDone: false);
    await tapText(tester, '시작하기');
    await tapText(tester, '다음');

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('삭제').first);
      await settle(tester);
    }
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byTooltip('카테고리는 최소 1개 필요해요'));
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('건너뛰기: 확인하면 예산 0원으로 홈에 들어가고 안내 배너가 보인다', (tester) async {
    await pumpApp(tester, onboardingDone: false);
    await tapText(tester, '건너뛰기');
    expect(find.text('온보딩을 건너뛸까요?'), findsOneWidget);
    await tapText(tester, '네, 건너뛸게요');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.textContaining('예산이 설정되지 않았어요'), findsOneWidget);
  });
}
