import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/receipt.dart';

/// 영수증 글자 샘플. 실제 영수증에서 잘못 읽은 경우가 나오면 여기에 더한다
/// (카드번호 등은 가려서).
final today = DateTime(2026, 11, 12, 20);

const convenienceStore = [
  'GS25 역삼점',
  '사업자번호 123-45-67890 대표 홍길동',
  '서울 강남구 테헤란로 123  TEL 02-123-4567',
  '2026-11-12 18:42:10  POS:01',
  '상품명  수량  금액',
  '삼각김밥참치마요  1  1,200',
  '(행사)바나나우유240ML  2  3,400',
  '1+1 행사할인  -1,700',
  '과세물품가액  2,627',
  '부가세  263',
  '합계  2,900',
  '받을금액  2,900',
  '신용카드  2,900',
  '카드번호 1234-56**-****-7890',
];

/// 품명과 숫자가 다른 줄로 읽힌 마트 영수증(바코드 줄 포함).
const mart = [
  '[영수증]',
  '(주)이마트 성수점',
  '전화 02-111-2222',
  '구매일시 2026.11.10 14:05',
  '001 P)서울우유1000ML',
  '8801115114154  2,800  1  2,800',
  '002 CJ)햇반210g*3',
  '8801007000000  4,500  1  4,500',
  '003 크리넥스 3겹 30롤',
  '8801166000000  12,000  1  12,000',
  '004 유리컵',
  '2,000  2  4,000',
  '행사할인  -1,300',
  '판매합계  23,300',
  '결제금액  22,000',
];

/// 금액이 다음 줄에 있는 카드 전표(품목 없음).
const cardSlip = [
  '신용카드 매출전표',
  '가맹점명: 스타벅스 강남점',
  '거래일시 26/11/11 09:12',
  '승인금액',
  '6,500원',
  '승인번호 12345678',
];

void main() {
  group('줄 맞추기', () {
    test('세로 위치가 겹치는 조각은 한 줄로, 왼쪽부터 잇는다', () {
      final rows = rowsFromLines(const [
        OcrLine('1,200', 300, 101, 360, 121),
        OcrLine('삼각김밥', 10, 100, 120, 120),
        OcrLine('1', 200, 102, 210, 119),
        OcrLine('합계', 10, 140, 60, 160),
        OcrLine('1,200', 300, 141, 360, 161),
      ]);
      expect(rows, ['삼각김밥  1  1,200', '합계  1,200']);
    });

    test('빈 입력은 빈 목록', () {
      expect(rowsFromLines(const []), isEmpty);
    });
  });

  group('편의점 영수증', () {
    final scan = parseReceipt(convenienceStore, today: today);

    test('결제 금액은 할인 뒤 "받을금액"(부가세·과세 줄은 무시)', () {
      expect(scan.total, 2900);
    });

    test('날짜·시간', () {
      expect(scan.date, DateTime(2026, 11, 12));
      expect(scan.time, '18:42');
    });

    test('구매처는 맨 위 상호 줄', () {
      expect(scan.place, 'GS25 역삼점');
    });

    test('품목: 할인 줄은 빼고, 이름은 정리한다', () {
      expect(scan.items.map((i) => (i.name, i.amount)), [
        ('삼각김밥참치마요', 1200),
        ('바나나우유', 3400),
      ]);
    });
  });

  group('마트 영수증', () {
    final scan = parseReceipt(mart, today: today);

    test('"판매합계"보다 "결제금액"이 먼저', () {
      expect(scan.total, 22000);
    });

    test('구매처: [영수증] 줄은 건너뛰고 (주)는 뺀다', () {
      expect(scan.place, '이마트 성수점');
    });

    test('날짜는 점으로 쓴 형식도', () {
      expect(scan.date, DateTime(2026, 11, 10));
      expect(scan.time, '14:05');
    });

    test('품명 줄과 숫자 줄이 나뉘어 있어도 한 품목으로 읽는다', () {
      expect(scan.items.map((i) => (i.name, i.amount)), [
        ('서울우유', 2800),
        ('햇반', 4500),
        ('크리넥스 3겹', 12000),
        ('유리컵', 4000),
      ]);
    });
  });

  group('카드 전표', () {
    final scan = parseReceipt(cardSlip, today: today);

    test('금액이 다음 줄에 있어도 찾는다(승인번호는 금액이 아님)', () {
      expect(scan.total, 6500);
    });

    test('가맹점명·두 자리 연도', () {
      expect(scan.place, '스타벅스 강남점');
      expect(scan.date, DateTime(2026, 11, 11));
      expect(scan.time, '09:12');
    });

    test('품목이 없으면 빈 목록', () {
      expect(scan.items, isEmpty);
    });
  });

  test('합계 말이 없으면 가장 큰 금액(전화번호·사업자번호는 빼고)', () {
    final scan = parseReceipt(const [
      '동네분식',
      '010-1234-5678',
      '떡볶이 4,000',
      '김밥 3,500',
    ], today: today);
    expect(scan.total, 7500, reason: '품목 합계');
    final noItems = parseReceipt(const [
      '동네분식',
      '010-1234-5678',
      '7,500원',
    ], today: today);
    expect(noItems.total, 7500);
  });

  test('미래 날짜나 1년 넘은 날짜는 잘못 읽은 것으로 보고 버린다', () {
    expect(parseReceipt(const ['2026-12-01'], today: today).date, isNull);
    expect(parseReceipt(const ['2025-10-01'], today: today).date, isNull);
    expect(parseReceipt(const ['2026-02-30'], today: today).date, isNull);
    expect(
      parseReceipt(const ['2026년 11월 3일 12:30'], today: today).date,
      DateTime(2026, 11, 3),
    );
  });

  group('품목 이름 정리', () {
    test('순번·앞 표시·용량·수량·행사 표시를 뺀다', () {
      expect(cleanItemName('001 P)서울우유1000ML'), '서울우유');
      expect(cleanItemName('CJ)햇반210g*3'), '햇반');
      expect(cleanItemName('(행사)크림빵 1+1'), '크림빵');
      expect(cleanItemName('[농협]사과 1.5kg'), '사과');
      expect(cleanItemName('코카콜라 500ml x2'), '코카콜라');
    });

    test('다 빼서 남는 게 없으면 원래 이름', () {
      expect(cleanItemName('(행사)'), '(행사)');
    });

    test('같은 상품 열쇠는 순번·바코드·띄어쓰기·대소문자와 상관없다', () {
      expect(itemKeyOf('001 P)서울우유1000ML'), itemKeyOf('P)서울우유 1000ml'));
      expect(placeKeyOf('(주)이마트  성수점'), placeKeyOf('이마트 성수점'));
    });
  });

  group('나눠 저장하기', () {
    const items = [
      ReceiptItem(key: 'a', name: '빵', amount: 3500),
      ReceiptItem(key: 'b', name: '우유', amount: 2800),
      ReceiptItem(key: 'c', name: '비누', amount: 4000),
      ReceiptItem(key: 'd', name: '컵', amount: 5000),
    ];

    test('카테고리가 하나면 결제 금액 그대로 한 건, 내역은 "외 N건", 메모는 품목 목록', () {
      final plan = planReceiptEntries(
        items: items,
        categoryOf: const [1, 1, 1, 1],
        total: 14000,
      );
      expect(plan.entries, hasLength(1));
      final e = plan.entries.single;
      expect(e.amount, 14000);
      expect(e.description, '빵 외 3건');
      expect(e.memo, '빵 3,500 / 우유 2,800 / 비누 4,000 / 컵 5,000');
      expect(plan.adjustedCategoryId, isNull);
    });

    test('여러 카테고리면 나누고, 할인은 금액이 가장 큰 쪽에서 한 번에 뺀다', () {
      final plan = planReceiptEntries(
        items: items,
        categoryOf: const [1, 1, 2, 2],
        total: 14000,
      );
      expect(plan.entries.map((e) => (e.categoryId, e.amount)), [
        (1, 6300),
        (2, 7700),
      ]);
      expect(plan.adjustment, 1300);
      expect(plan.adjustedCategoryId, 2);
      expect(
        plan.entries.fold<int>(0, (s, e) => s + e.amount),
        14000,
        reason: '합계는 결제 금액과 같다',
      );
      expect(plan.entries.first.description, '빵 외 1건');
      expect(plan.entries.last.memo, '비누 4,000 / 컵 5,000');
    });

    test('품목 합계가 결제 금액보다 적으면 가장 큰 쪽에 더한다', () {
      final plan = planReceiptEntries(
        items: items,
        categoryOf: const [1, 1, 2, 2],
        total: 16000,
      );
      expect(plan.entries.map((e) => e.amount), [6300, 9700]);
      expect(plan.adjustment, -700);
    });

    test('차이가 없으면 손대지 않는다', () {
      final plan = planReceiptEntries(
        items: items,
        categoryOf: const [1, 2, 1, 2],
        total: 15300,
      );
      expect(plan.entries.map((e) => e.amount), [7500, 7800]);
      expect(plan.adjustedCategoryId, isNull);
    });

    test('품목이 없으면 고른 카테고리로 결제 금액 한 건', () {
      final plan = planReceiptEntries(
        items: const [],
        categoryOf: const [],
        total: 6500,
        fallbackCategoryId: 3,
      );
      expect(plan.entries.single.amount, 6500);
      expect(plan.entries.single.categoryId, 3);
      expect(plan.entries.single.description, '');
    });
  });
}
