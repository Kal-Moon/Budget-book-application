import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/ui/import/import_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pump.dart';

PickedImportFile csvFile(String name, String content) =>
    (name: name, bytes: Uint8List.fromList(utf8.encode(content)));

/// 편한가계부 내보내기와 같은 열 구성.
const pyeonhanCsv = '''
날짜,자산,분류,소분류,내용,KRW,수입/지출,메모,금액,화폐,자산
2026-11-08 12:30,현금,식비,,점심,12000,지출,맛있음,12000,KRW,12000
2026-11-07 09:00,카드,의료,,감기약,8000,지출,,8000,KRW,8000
2026-11-06,카드,,,분류 없음,3000,지출,,3000,KRW,3000
2026-11-01,통장,월급,,11월 급여,2000000,수입,,2000000,KRW,2000000
합계,,,,,,,,2023000,,
''';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    // 스크롤한 위치가 화면에 반영된 뒤에 누른다.
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> openImportScreen(WidgetTester tester) async {
    await tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('설정'),
      ),
    );
    await tap(tester, find.text('다른 가계부에서 가져오기'));
  }

  Finder nextButton() => find.byType(FilledButton);

  testWidgets('편한가계부 파일: 열을 알아서 맞추고, 분류를 연결해 가져온다', (tester) async {
    final db = await pumpApp(
      tester,
      importFile: csvFile('편한가계부.csv', pyeonhanCsv.trimLeft()),
    );
    await openImportScreen(tester);
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNull);

    await tap(tester, find.text('파일 선택'));
    expect(find.text('편한가계부.csv'), findsOneWidget);
    expect(find.text('5줄'), findsOneWidget);
    await tap(tester, nextButton());

    // 열 확인: 금액은 9열(금액), 구분은 "별도 열로" + 7열(수입/지출)
    expect(find.text('항목을 확인해주세요'), findsOneWidget);
    expect(find.text('9열: 금액'), findsOneWidget);
    expect(find.text('7열: 수입/지출'), findsOneWidget);
    expect(find.text('5열: 내용'), findsOneWidget);
    await tap(tester, nextButton());

    // 카테고리 연결: 지출·수입을 나눠서, 같은 이름은 자동 연결, 없는 건 새로 만들기
    expect(find.text('지출 분류'), findsOneWidget);
    expect(find.text('수입 분류'), findsOneWidget);
    expect(find.text('🍚 식비'), findsOneWidget);
    expect(find.text('💼 월급'), findsOneWidget);
    expect(find.text('✨ 새 카테고리로 만들기'), findsOneWidget, reason: '의료');
    expect(find.textContaining('분류가 비어 있는 내역은 "미분류"'), findsOneWidget);
    await tap(tester, nextButton());

    // 미리보기
    expect(find.text('4건'), findsOneWidget);
    expect(find.text('기존 2개 연결 · 1개 신규'), findsOneWidget);
    expect(find.text('23,000원'), findsOneWidget);
    expect(find.text('2,000,000원'), findsOneWidget);
    expect(find.text('읽지 못한 행'), findsOneWidget);
    expect(find.text('1건'), findsOneWidget, reason: '합계 줄');
    await tap(tester, find.text('가져오기'));

    expect(find.text('가져오기 완료!'), findsOneWidget);
    expect(find.textContaining('지출 3건, 수입 1건을 가져왔어요.'), findsOneWidget);
    await tap(tester, find.text('완료'));

    // 홈에서 바로 보인다
    expect(find.text('11월 지출'), findsOneWidget);
    expect(find.text('점심'), findsOneWidget);
    expect(find.text('11월 급여'), findsOneWidget);
    expect(find.text('미분류'), findsWidgets);

    final entries = await tester.runAsync(() => db.select(db.entries).get());
    expect(entries, hasLength(4));
    final lunch = entries!.firstWhere((e) => e.description == '점심');
    expect(
      (lunch.date, lunch.time, lunch.memo),
      ('2026-11-08', '12:30', '맛있음'),
    );
    final expense = await tester.runAsync(
      () => db.watchCategories(EntryKind.expense).first,
    );
    expect(expense!.map((c) => c.name), containsAll(['의료', '미분류']));
  });

  testWidgets('분류를 다른 카테고리에 합칠 수 있다', (tester) async {
    final db = await pumpApp(
      tester,
      importFile: csvFile('a.csv', '날짜,금액,분류\n2026-11-08,-8000,의료\n'),
    );
    await openImportScreen(tester);
    await tap(tester, find.text('파일 선택'));
    await tap(tester, nextButton());
    expect(find.text('금액 부호로'), findsOneWidget);
    await tap(tester, nextButton());

    await tap(tester, find.byKey(const ValueKey('cat-expense-의료')));
    await tap(tester, find.text('🛍️ 쇼핑').last);
    await tap(tester, nextButton());
    expect(find.text('기존 1개 연결 · 0개 신규'), findsOneWidget);
    await tap(tester, find.text('가져오기'));

    final entries = await tester.runAsync(() => db.select(db.entries).get());
    expect(entries!.single.categoryId, 4);
    final expense = await tester.runAsync(
      () => db.watchCategories(EntryKind.expense).first,
    );
    expect(expense, hasLength(4), reason: '새 카테고리를 만들지 않음');
  });

  testWidgets('읽을 수 없는 파일은 이유를 보여주고 다음으로 갈 수 없다', (tester) async {
    await pumpApp(tester, importFile: csvFile('옛날.xls', 'x'));
    await openImportScreen(tester);
    await tap(tester, find.text('파일 선택'));
    expect(find.textContaining('옛 엑셀 형식(.xls)은 읽을 수 없어요'), findsOneWidget);
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNull);
  });

  testWidgets('날짜·금액 열을 못 찾으면 직접 고르게 한다', (tester) async {
    await pumpApp(
      tester,
      importFile: csvFile('b.csv', '언제,얼마\n2026-11-08,-4500\n'),
    );
    await openImportScreen(tester);
    await tap(tester, find.text('파일 선택'));
    await tap(tester, nextButton());
    await tap(tester, nextButton());
    expect(find.text('날짜와 금액 열은 반드시 지정해야 해요.'), findsOneWidget);

    await tap(tester, find.byKey(const ValueKey('map-날짜')));
    await tap(tester, find.text('1열: 언제').last);
    await tap(tester, find.byKey(const ValueKey('map-금액')));
    await tap(tester, find.text('2열: 얼마').last);
    await tap(tester, nextButton());
    expect(find.text('카테고리를 연결해주세요'), findsOneWidget);
    expect(find.textContaining('모든 내역이 "미분류" 카테고리로'), findsOneWidget);
  });
}
