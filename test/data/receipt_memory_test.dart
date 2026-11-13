import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';

import '../helpers.dart';

ReceiptMemoriesCompanion item(String key, String name, int? categoryId) =>
    ReceiptMemoriesCompanion.insert(
      kind: ReceiptMemoryKind.item,
      key: key,
      name: Value(name),
      categoryId: Value(categoryId),
    );

void main() {
  test('예전 버전(1) DB를 열면 기존 내역은 그대로 두고 영수증 기억 표를 만든다', () async {
    final dir = await Directory.systemTemp.createTemp('gagyebu_migrate');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    AppDatabase open() => AppDatabase(
      DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
    );

    // 버전 1 상태를 만든다: 영수증 기억 표가 없고 user_version이 1.
    final old = open();
    await addEntry(old, date: '2026-11-01', categoryId: 1, amount: 5000);
    await old.customStatement('DROP TABLE receipt_memories');
    await old.customStatement('PRAGMA user_version = 1');
    await old.close();

    final db = open();
    addTearDown(db.close);
    expect(await db.select(db.entries).get(), hasLength(1));
    expect(await db.getReceiptMemories(), isEmpty);
    await db.saveReceiptEntries(const [], [item('우유', '우유', 1)]);
    expect(await db.getReceiptMemories(), hasLength(1));
  });

  group('영수증 기억', () {
    late AppDatabase db;
    setUp(() => db = memoryDatabase());
    tearDown(() => db.close());

    test('같은 열쇠는 마지막 선택으로 덮어쓰고, 내역과 함께 저장한다', () async {
      await db.saveReceiptEntries(
        [
          EntriesCompanion.insert(
            kind: EntryKind.expense,
            date: '2026-11-12',
            time: '18:42',
            categoryId: 1,
            amount: 2900,
          ),
        ],
        [item('p)서울우유1000ml', '우유', 1)],
      );
      await db.saveReceiptEntries(const [], [item('p)서울우유1000ml', '흰우유', 3)]);
      final m = (await db.getReceiptMemories()).single;
      expect((m.name, m.categoryId), ('흰우유', 3));
      expect(await db.select(db.entries).get(), hasLength(1));
    });

    test('카테고리를 합치면(옮기며 삭제) 기억도 옮겨진다', () async {
      await db.saveReceiptEntries(const [], [item('빵', '빵', 3)]);
      await db.deleteCategory(3, moveTo: 1);
      expect((await db.getReceiptMemories()).single.categoryId, 1);
    });

    test('카테고리를 그냥 지우면 카테고리만 비우고 이름 기억은 남는다', () async {
      await db.saveReceiptEntries(const [], [item('빵', '크림빵', 3)]);
      await db.deleteCategory(3);
      final m = (await db.getReceiptMemories()).single;
      expect(m.categoryId, isNull);
      expect(m.name, '크림빵');
    });

    test('내역 데이터 초기화와 "영수증 기억 지우기"로 지워진다', () async {
      await db.saveReceiptEntries(const [], [item('빵', '빵', 3)]);
      await db.clearRecords();
      expect(await db.getReceiptMemories(), isEmpty);
      // 초기화하면 카테고리 id가 새로 매겨진다(그래서 기억도 함께 지워야 한다).
      await db.saveReceiptEntries(const [], [item('빵', '빵', null)]);
      await db.clearReceiptMemories();
      expect(await db.getReceiptMemories(), isEmpty);
    });
  });
}
