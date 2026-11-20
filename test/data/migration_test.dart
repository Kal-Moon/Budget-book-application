import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';

import '../helpers.dart';

void main() {
  // 테스트 빌드 26~29를 쓰던 폰: 버전 2 DB에 영수증 기억 표가 있다.
  // 영수증 입력을 빼면서(버전 3) 그 표만 지우고 내역은 그대로 둔다.
  test('버전 2 DB를 열면 영수증 기억 표를 지우고 내역은 남긴다', () async {
    final dir = await Directory.systemTemp.createTemp('gagyebu_v3');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    AppDatabase open() => AppDatabase(
      DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
    );

    final old = open();
    await addEntry(old, date: '2026-11-16', categoryId: 1, amount: 1700);
    await old.customStatement(
      'CREATE TABLE receipt_memories (kind INTEGER NOT NULL, key TEXT NOT NULL, '
      "name TEXT NOT NULL DEFAULT '', category_id INTEGER, PRIMARY KEY (kind, key))",
    );
    await old.customStatement(
      "INSERT INTO receipt_memories VALUES (0, '우유', '우유', 1)",
    );
    await old.customStatement('PRAGMA user_version = 2');
    await old.close();

    final db = open();
    addTearDown(db.close);
    expect(await db.select(db.entries).get(), hasLength(1));
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'receipt_memories'",
        )
        .get();
    expect(tables, isEmpty);
  });

  test('버전 3 DB를 열면 고정 지출 표를 만들고 내역은 남긴다', () async {
    final dir = await Directory.systemTemp.createTemp('gagyebu_v4');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    AppDatabase open() => AppDatabase(
      DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
    );

    final old = open();
    await addEntry(old, date: '2026-11-16', categoryId: 1, amount: 1700);
    await old.customStatement('DROP TABLE fixed_expenses');
    await old.customStatement('PRAGMA user_version = 3');
    await old.close();

    final db = open();
    addTearDown(db.close);
    expect(await db.select(db.entries).get(), hasLength(1));
    await db.saveFixedExpense(
      name: '월세',
      categoryId: 1,
      amount: 500000,
      day: 25,
      today: '2026-11-20',
    );
    expect(await db.watchFixedExpenses().first, hasLength(1));
  });
}
