import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'pump.dart';

/// 기준 시각 2026-11-08 10:00.
void main() {
  testWidgets('설정에서 고정 지출을 추가하면 목록에 보이고, 오늘이 그날이면 바로 입력한다', (tester) async {
    final db = await pumpApp(tester);
    await openTab(tester, '설정');
    expect(find.text('0개 ›'), findsOneWidget);
    await tap(tester, find.text('고정 지출 관리'));
    expect(find.text('아직 고정 지출이 없어요'), findsOneWidget);
    await tap(tester, find.text('고정 지출 추가'));

    final save = find.widgetWithText(FilledButton, '저장');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('fixed-name')), '월세');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('fixed-amount')),
        matching: find.byType(TextField),
      ),
      '500000',
    );
    await settle(tester);
    await tap(tester, find.byKey(const ValueKey('fixed-category')));
    await tap(tester, find.text('식비').last);
    expect(find.text('🍚 식비'), findsOneWidget);
    await tap(tester, save);

    expect(
      find.text('✓ 저장하고 오늘 내역으로 입력했어요'),
      findsOneWidget,
      reason: '기본 날짜는 오늘(8일)',
    );
    expect(find.text('월세'), findsOneWidget);
    expect(find.text('매달 8일 · 500,000원'), findsOneWidget);
    expect(find.text('다음 입력: 12월 8일'), findsOneWidget);
    final entries = await tester.runAsync(() => db.select(db.entries).get());
    expect(entries!.single.description, '월세');
  });

  testWidgets('앱을 열 때 날이 지난 고정 지출을 입력하고 알린다', (tester) async {
    await pumpApp(
      tester,
      setup: (db) async {
        await db.saveFixedExpense(
          name: '통신비',
          categoryId: 2,
          amount: 55000,
          day: 5,
          today: '2026-10-01',
        );
      },
    );
    expect(find.text('고정 지출 2건을 입력했어요'), findsOneWidget, reason: '10/5, 11/5');
    expect(find.text('통신비'), findsOneWidget, reason: '홈 11월 목록');
  });

  testWidgets('켜 둔 채 날짜가 바뀌어 그날이 되면 입력한다', (tester) async {
    final clock = FakeClock(DateTime(2026, 11, 8, 23, 59));
    final db = await pumpApp(
      tester,
      clock: clock,
      setup: (db) => db.saveFixedExpense(
        name: '구독',
        categoryId: 4,
        amount: 9900,
        day: 9,
        today: '2026-11-08',
      ),
    );
    expect(find.text('구독'), findsNothing);
    clock.current = DateTime(2026, 11, 9, 0, 1);
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);
    expect(find.text('고정 지출 1건을 입력했어요'), findsOneWidget);
    final entries = await tester.runAsync(() => db.select(db.entries).get());
    expect(entries!.single.date, '2026-11-09');
  });
}
