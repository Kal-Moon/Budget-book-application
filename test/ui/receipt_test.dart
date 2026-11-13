import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/receipt.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';
import 'pump.dart';

/// 기준 시각은 2026-11-08 10:00(pumpApp).
const martRows = [
  '(주)이마트 성수점',
  '전화 02-111-2222',
  '구매일시 2026.11.07 14:05',
  '001 P)서울우유1000ML',
  '8801115114154  2,800  1  2,800',
  '002 CJ)햇반210g*3',
  '8801007000000  4,500  1  4,500',
  '003 크리넥스 3겹 30롤',
  '8801166000000  12,000  1  12,000',
  '004 유리컵',
  '2,000  2  4,000',
  '행사할인  -1,300',
  '결제금액  22,000',
];

const slipRows = [
  '신용카드 매출전표',
  '가맹점명: 스타벅스 강남점',
  '거래일시 26/11/07 09:12',
  '승인금액',
  '6,500원',
];

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    // 스크롤한 위치가 화면에 반영된 뒤에 누른다.
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> scanReceipt(WidgetTester tester) async {
    await tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('입력'),
      ),
    );
    await tap(tester, find.text('영수증으로 입력'));
    await tap(tester, find.text('사진 찍기'));
    expect(find.text('영수증 확인'), findsOneWidget);
  }

  Future<List<Entry>> entriesOf(WidgetTester tester, AppDatabase db) async =>
      (await tester.runAsync(() => db.select(db.entries).get()))!;

  testWidgets('마트 영수증: 품목마다 카테고리를 고르면 나눠 저장하고, 할인은 큰 쪽에서 뺀다', (tester) async {
    final db = await pumpApp(tester, receiptRows: martRows);
    await scanReceipt(tester);

    expect(find.text('22,000'), findsOneWidget, reason: '결제 금액');
    expect(find.text('2026.11.07'), findsOneWidget);
    expect(find.text('이마트 성수점'), findsOneWidget);
    expect(find.text('품목 4개'), findsOneWidget);
    expect(find.text('모든 품목의 카테고리를 골라주세요'), findsOneWidget);

    await tap(tester, find.text('전부 🍚 식비'));
    expect(find.text('저장될 내역 (1건)'), findsOneWidget);
    // 크리넥스·유리컵은 쇼핑으로.
    for (var n = 0; n < 2; n++) {
      await tap(tester, find.text('🍚 식비 ▾').at(2));
      await tap(tester, find.text('쇼핑').last);
    }
    expect(find.text('저장될 내역 (2건)'), findsOneWidget);
    expect(find.text("할인 등 1,300원은 '쇼핑'에서 뺐어요"), findsOneWidget);
    await tap(tester, find.text('저장 (2건)'));

    expect(find.text('영수증을 2건으로 나눠 저장했어요'), findsOneWidget);
    final rows = await entriesOf(tester, db);
    expect(rows.map((e) => (e.categoryId, e.amount)), [(1, 7300), (4, 14700)]);
    final food = rows.first;
    expect(food.date, '2026-11-07');
    expect(food.time, '14:05');
    expect(food.place, '이마트 성수점');
    expect(food.description, '서울우유 외 1건');
    expect(food.memo, '서울우유 2,800 / 햇반 4,500');

    // 저장할 때 고른 이름·카테고리를 기억한다.
    final memories = (await tester.runAsync(db.getReceiptMemories))!;
    final milk = memories.firstWhere(
      (m) => m.key == itemKeyOf('001 P)서울우유1000ML'),
    );
    expect(milk.categoryId, 1);
    final place = memories.firstWhere((m) => m.kind == ReceiptMemoryKind.place);
    expect(place.categoryId, 4, reason: '금액이 가장 큰 카테고리');
  });

  testWidgets('기억해 둔 이름·카테고리가 미리 채워지고, 품목을 고치거나 뺄 수 있다', (tester) async {
    final db = await pumpApp(
      tester,
      receiptRows: martRows,
      setup: (db) => db.saveReceiptEntries(const [], [
        for (final (raw, name, cat) in [
          ('001 P)서울우유1000ML', '우유', 1),
          ('002 CJ)햇반210g*3', '햇반', 1),
          ('003 크리넥스 3겹 30롤', '휴지', 4),
        ])
          ReceiptMemoriesCompanion.insert(
            kind: ReceiptMemoryKind.item,
            key: itemKeyOf(raw),
            name: Value(name),
            categoryId: Value(cat),
          ),
        ReceiptMemoriesCompanion.insert(
          kind: ReceiptMemoryKind.place,
          key: placeKeyOf('이마트 성수점'),
          categoryId: const Value(4),
        ),
      ]),
    );
    await scanReceipt(tester);

    expect(find.text('우유'), findsOneWidget);
    expect(find.text('휴지'), findsOneWidget);
    expect(find.text('🍚 식비 ▾'), findsNWidgets(2));
    expect(
      find.text('🛍️ 쇼핑 ▾'),
      findsNWidgets(2),
      reason: '유리컵은 기억이 없어 구매처 기억(쇼핑)으로',
    );

    // 유리컵을 빼고, 결제 금액을 고친다.
    await tap(tester, find.byTooltip('이 품목 빼기').last);
    expect(find.text('품목 3개'), findsOneWidget);
    await tester.enterText(find.text('22,000'), '18000');
    await settle(tester);
    // 휴지 이름 고치기.
    await tap(tester, find.text('휴지'));
    await tester.enterText(find.widgetWithText(TextField, '휴지'), '두루마리휴지');
    await settle(tester);
    await tap(tester, find.text('확인'));
    expect(find.text('두루마리휴지'), findsOneWidget);

    await tap(tester, find.text('저장 (2건)'));
    final rows = await entriesOf(tester, db);
    expect(rows.map((e) => e.amount).fold<int>(0, (s, a) => s + a), 18000);
    final memories = (await tester.runAsync(db.getReceiptMemories))!;
    expect(
      memories.firstWhere((m) => m.key == itemKeyOf('003 크리넥스 3겹 30롤')).name,
      '두루마리휴지',
    );
  });

  testWidgets('품목이 없는 카드 전표: 같은 구매처의 지난 내역 카테고리로 한 건 저장', (tester) async {
    final db = await pumpApp(
      tester,
      receiptRows: slipRows,
      setup: (db) => addEntry(
        db,
        date: '2026-11-01',
        categoryId: 3,
        amount: 4500,
        place: '스타벅스 강남점',
      ),
    );
    await scanReceipt(tester);

    expect(find.text('6,500'), findsOneWidget);
    expect(find.text('09:12'), findsOneWidget);
    expect(find.textContaining('품목을 찾지 못했어요'), findsOneWidget);
    expect(find.text('☕ 카페 ▾'), findsOneWidget);
    await tap(tester, find.text('저장'));

    expect(find.text('영수증 내역을 저장했어요'), findsOneWidget);
    final rows = await entriesOf(tester, db);
    final saved = rows.firstWhere((e) => e.amount == 6500);
    expect(saved.categoryId, 3);
    expect(saved.date, '2026-11-07');
    expect(saved.description, '');
  });

  testWidgets('글자를 못 찾거나 사진을 안 고르면 확인 화면으로 가지 않는다', (tester) async {
    await pumpApp(tester, receiptRows: const []);
    await tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('입력'),
      ),
    );
    await tap(tester, find.text('영수증으로 입력'));
    await tap(tester, find.text('앨범에서 고르기'));
    expect(find.text('영수증 확인'), findsNothing);
    expect(find.textContaining('글자를 찾지 못했어요'), findsOneWidget);
  });

  testWidgets('취소하면 아무것도 저장하지 않는다', (tester) async {
    final db = await pumpApp(tester, receiptRows: slipRows);
    await scanReceipt(tester);
    await tap(tester, find.text('취소'));
    expect(find.text('영수증 확인'), findsNothing);
    expect(await entriesOf(tester, db), isEmpty);
  });

  testWidgets('설정에서 영수증 기억을 지울 수 있다(내역은 그대로)', (tester) async {
    final db = await pumpApp(
      tester,
      setup: (db) async {
        await addEntry(db, date: '2026-11-01', categoryId: 1, amount: 1000);
        await db.saveReceiptEntries(const [], [
          ReceiptMemoriesCompanion.insert(
            kind: ReceiptMemoryKind.item,
            key: '빵',
            categoryId: const Value(1),
          ),
        ]);
      },
    );
    await tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('설정'),
      ),
    );
    await tap(tester, find.text('영수증 기억 지우기'));
    await tap(tester, find.text('지우기'));
    expect(find.text('영수증 기억을 지웠어요'), findsOneWidget);
    expect(await tester.runAsync(db.getReceiptMemories), isEmpty);
    expect(await entriesOf(tester, db), hasLength(1));
  });
}
