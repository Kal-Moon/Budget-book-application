import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/import.dart';

import '../helpers.dart';

ImportRow row(
  String category, {
  EntryKind kind = EntryKind.expense,
  int amount = 1000,
}) => ImportRow(
  kind: kind,
  date: '2026-11-08',
  time: '12:00',
  amount: amount,
  categoryRaw: category,
  place: '',
  description: '',
  memo: '',
);

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<Map<int, Category>> categories() async => {
    for (final c in await db.watchAllCategories().first) c.id: c,
  };

  /// 모든 내역이 실제로 있는 카테고리를 가리키는지, 그리고 그 이름들.
  Future<List<String>> entryCategoryNames() async {
    final cats = await categories();
    final entries = await db.select(db.entries).get();
    return [for (final e in entries) cats[e.categoryId]!.name];
  }

  test('연결한 카테고리로 넣고, 새 분류는 만들고, 빈 분류는 종류별 미분류로', () async {
    final (expense, income) = await db.importEntries(
      [
        row('식비'),
        row('의료'),
        row('의료'),
        row(''),
        row('', kind: EntryKind.income),
        row('월급', kind: EntryKind.income),
      ],
      {
        EntryKind.expense: {'식비': 1, '의료': null},
        EntryKind.income: {'월급': 5},
      },
    );
    expect((expense, income), (4, 2));
    expect(await entryCategoryNames(), ['식비', '의료', '의료', '미분류', '미분류', '월급']);

    final cats = (await categories()).values;
    expect(cats.where((c) => c.name == '의료'), hasLength(1), reason: '한 번만 생성');
    final uncategorized = cats.where((c) => c.name == '미분류');
    expect(uncategorized.map((c) => c.kind).toSet(), {
      EntryKind.expense,
      EntryKind.income,
    });
  });

  // 회귀 테스트: 이전 앱은 미분류 카테고리 id를 기억해 두고 재사용해서,
  // 초기화하거나 미분류를 지운 뒤 다시 가져오면 내역이 사라지거나 엉뚱한 카테고리에 붙었다.
  test('초기화 → 가져오기: 미분류를 새로 만들어 제대로 연결한다', () async {
    await db.importEntries([row('')], const {});
    await db.clearRecords();

    await db.importEntries([row(''), row('의료')], const {});

    expect(await entryCategoryNames(), ['미분류', '의료']);
  });

  test('미분류 삭제 → 가져오기: 다시 만들어 제대로 연결한다', () async {
    await db.importEntries([row('')], const {});
    final first = (await categories()).values.singleWhere(
      (c) => c.name == '미분류',
    );
    await db.deleteCategory(first.id);

    await db.importEntries([row(''), row('의료')], const {});

    expect(await entryCategoryNames(), ['미분류', '의료']);
  });

  test('연결하려던 카테고리가 그사이 삭제됐으면 분류 이름으로 새로 만든다', () async {
    await db.deleteCategory(3);
    await db.importEntries(
      [row('카페')],
      {
        EntryKind.expense: {'카페': 3},
      },
    );
    expect(await entryCategoryNames(), ['카페']);
  });

  test('새 분류 이름이 이미 있으면 합치고, 8자를 넘으면 앞 8자로 만든다', () async {
    await db.importEntries([
      row('식비'),
      row('가나다라마바사아자차'),
      row('가나다라마바사아'),
    ], const {});
    expect(await entryCategoryNames(), ['식비', '가나다라마바사아', '가나다라마바사아']);
    final expense = await db.watchCategories(EntryKind.expense).first;
    expect(expense, hasLength(5), reason: '기본 4개 + 1개');
  });

  test('같은 이름이라도 지출·수입 카테고리는 따로다', () async {
    await db.importEntries([
      row('용돈'),
      row('용돈', kind: EntryKind.income),
    ], const {});
    final cats = (await categories()).values.where((c) => c.name == '용돈');
    expect(cats, hasLength(2));
    final entries = await db.select(db.entries).get();
    final byId = await categories();
    for (final e in entries) {
      expect(byId[e.categoryId]!.kind, e.kind);
    }
  });
}
