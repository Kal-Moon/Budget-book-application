import 'dart:math' as math;

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

/// 사진 속 영수증을 재현한다: 반듯한 배치(x0, x1, y, 높이)를 [degrees]만큼 기울여
/// 글자 인식기처럼 기울어진 조각의 바깥 상자를 만든다(오른쪽이 올라가면 음수).
List<OcrLine> tilted(
  List<(String, double, double, double, double)> layout, {
  double degrees = -2,
}) {
  final k = math.tan(degrees * math.pi / 180);
  return [
    for (final (text, x0, x1, y, h) in layout)
      OcrLine(
        text,
        x0,
        math.min(y + x0 * k, y + x1 * k),
        x1,
        math.max(y + h + x0 * k, y + h + x1 * k),
        angle: degrees,
      ),
  ];
}

/// 빌드 26에서 사용자가 찍은 카페 영수증(삼성웰스토리, 2026-11-16) 배치.
/// 오른쪽이 살짝 올라가 있어서, 예전 규칙은 상호 줄과 주소 줄을 섞고("동스토리 크랜프톤정e
/// 여문리 46-27"), 아메리카노에 공급가액 1,546을 붙이고, 결제 금액을 3,246으로 읽었다.
final cafeReceipt = tilted([
  ('[영수증]', 500, 900, 0, 60),
  ('교환권 번호 : 001', 100, 520, 70, 42),
  ('삼성웰스토리 크래프톤정글', 100, 710, 120, 42),
  ('경기도 용인시 처인구 포곡읍', 90, 700, 165, 42),
  ('영문리 46-27 크래프톤', 720, 1330, 165, 42),
  ('정글', 110, 190, 210, 42),
  ('6748502577 / 송규종 / TEL : 031-111-1111', 90, 1090, 260, 42),
  ('주문번호 : 20260010023125', 90, 740, 305, 42),
  ('주문일시 : 2026-11-16 09:06:31', 90, 830, 350, 42),
  ('상품명', 90, 230, 430, 42),
  ('수량', 1200, 1300, 430, 42),
  ('아메리카노 HOT', 90, 420, 520, 42),
  ('1', 1280, 1300, 520, 42),
  ('공급가액', 90, 260, 610, 42),
  ('1,546', 1180, 1310, 610, 42),
  ('부 가 세', 90, 260, 655, 42),
  ('154', 1230, 1310, 655, 42),
  ('합 계', 90, 300, 740, 42),
  ('1,700', 1180, 1310, 740, 42),
  ('결제금액', 90, 270, 790, 70),
  ('1,700', 1180, 1310, 790, 70),
  ('신용카드 : 1,700', 90, 470, 900, 42),
  ('할부개월 : 00', 90, 400, 945, 42),
  ('승인번호 : 77869822', 90, 540, 990, 42),
  ('카드번호 : 971015*********', 90, 740, 1035, 42),
  ('가맹점번호 : 199432256', 90, 620, 1080, 42),
]);

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

    test('기울어진 사진: 위아래로 붙은 줄은 섞지 않고, 오른쪽 숫자는 같은 줄에 붙인다', () {
      final rows = rowsFromLines(cafeReceipt);
      expect(rows, contains('삼성웰스토리 크래프톤정글'));
      expect(rows, contains('경기도 용인시 처인구 포곡읍  영문리 46-27 크래프톤'));
      expect(rows, contains('아메리카노 HOT  1'));
      expect(rows, contains('공급가액  1,546'));
      expect(rows, contains('결제금액  1,700'));
    });

    test('기울기 방향이 반대로 와도 같은 결과', () {
      final flipped = [
        for (final l in cafeReceipt)
          OcrLine(l.text, l.left, l.top, l.right, l.bottom, angle: -l.angle),
      ];
      expect(rowsFromLines(flipped), rowsFromLines(cafeReceipt));
    });

    test('빈 입력은 빈 목록', () {
      expect(rowsFromLines(const []), isEmpty);
    });
  });

  group('카페 영수증(빌드 26 사용자 사진 재현)', () {
    final scan = parseReceipt(
      rowsFromLines(cafeReceipt),
      today: DateTime(2026, 11, 16, 10),
    );

    test('결제 금액 1,700(품목 합계 3,246이 아니라)', () {
      expect(scan.total, 1700);
    });

    test('구매처는 상호 줄', () {
      expect(scan.place, '삼성웰스토리 크래프톤정글');
    });

    test('날짜·시간', () {
      expect(scan.date, DateTime(2026, 11, 16));
      expect(scan.time, '09:06');
    });

    test('가격 없는 품목 하나는 결제 금액으로, 카드 정보 줄은 품목이 아니다', () {
      expect(scan.items.map((i) => (i.name, i.amount)), [('아메리카노 HOT', 1700)]);
    });
  });

  test('합계 말을 못 읽어도 여러 번 나오는 금액을 결제 금액으로', () {
    final scan = parseReceipt(const [
      '동네카페',
      '상품명  수량',
      '라떼  1',
      '공급가액  4,091',
      '부가세  409',
      '합  4,500',
      '갈제금역  4,500',
      '카드 : 4,500',
    ], today: today);
    expect(scan.total, 4500);
    expect(scan.items.single.amount, 4500, reason: '가격 없는 품목 하나');
  });

  test('가격 없는 품목이 여럿이면 품목 없이 한 건, 이름은 내역·메모로', () {
    final scan = parseReceipt(const [
      '동네카페',
      '상품명  수량',
      '라떼  1',
      '쿠키  2',
      '결제금액  8,000',
    ], today: today);
    expect(scan.items, isEmpty);
    expect(scan.unpricedNames, ['라떼', '쿠키']);
    final plan = planReceiptEntries(
      items: const [],
      categoryOf: const [],
      total: scan.total!,
      fallbackCategoryId: 3,
      unpricedNames: scan.unpricedNames,
    );
    expect(plan.entries.single.description, '라떼 외 1건');
    expect(plan.entries.single.memo, '라떼 / 쿠키');
    expect(plan.entries.single.amount, 8000);
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
