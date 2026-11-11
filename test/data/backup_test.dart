import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/backup.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/data/settings.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = memoryDatabase();
    target = memoryDatabase();
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  final now = DateTime(2026, 11, 11, 10, 30);

  /// 여러 종류의 기록이 있는 DB를 만든다.
  Future<void> fill(AppDatabase db) async {
    final pet = await db.addCategory(
      kind: EntryKind.expense,
      name: '반려동물',
      icon: '🐶',
      color: 0xFF7C9CBF,
    );
    await db.deleteCategory(4); // 쇼핑을 지워서 id에 빈자리가 생긴다.
    await db.saveMonthBudget(
      const MonthBudget(
        monthKey: '2026-10',
        mode: BudgetMode.total,
        total: 500000,
      ),
    );
    await db.saveMonthBudget(
      MonthBudget(
        monthKey: '2026-11',
        mode: BudgetMode.category,
        categoryAmounts: {1: 200000, pet: 30000},
      ),
    );
    await addEntry(
      db,
      date: '2026-11-03',
      time: '08:15',
      categoryId: pet,
      amount: 25000,
      place: '동물병원',
      description: '예방접종',
      memo: '다음 달에 2차',
    );
    await addEntry(
      db,
      kind: EntryKind.income,
      date: '2026-10-25',
      categoryId: 5,
      amount: 3000000,
      description: '10월 급여',
    );
  }

  Future<BackupFile> roundTrip(AppDatabase from) async {
    final bytes = await createBackup(from, settings: const {}, now: now);
    return parseBackup(bytes, schemaVersion: target.schemaVersion);
  }

  test('백업 → 복원: 내역·카테고리·예산이 id까지 똑같이 돌아온다', () async {
    await fill(source);
    final backup = await roundTrip(source);
    expect(backup.createdAt, now);
    expect(backup.entryCount, 2);
    expect(backup.categoryCount, 8);

    await restoreRecords(target, backup);

    expect(await target.exportAllTables(), await source.exportAllTables());
    final nov = await target.getMonthBudget('2026-11');
    expect(nov.mode, BudgetMode.category);
    expect(nov.totalBudget, 230000);
    // 복원한 뒤 새로 추가해도 id가 겹치지 않는다.
    final added = await target.addCategory(
      kind: EntryKind.expense,
      name: '새 항목',
      icon: '✨',
      color: 0,
    );
    expect(added, greaterThan(9));
  });

  test('복원하면 지금 기록은 모두 사라지고 백업 내용만 남는다(합치지 않는다)', () async {
    await fill(source);
    await addEntry(target, date: '2026-11-10', categoryId: 3, amount: 4500);
    await target.saveMonthBudget(
      const MonthBudget(monthKey: '2026-12', mode: BudgetMode.total, total: 1),
    );

    await restoreRecords(target, await roundTrip(source));

    final entries = await target.select(target.entries).get();
    expect(entries.map((e) => e.amount), unorderedEquals([25000, 3000000]));
    expect((await target.getMonthBudget('2026-12')).isSet, isFalse);
    final expense = await target.watchCategories(EntryKind.expense).first;
    expect(expense.map((c) => c.name), ['식비', '교통', '카페', '반려동물']);
  });

  group('읽을 수 없는 파일', () {
    Matcher fails(String message) => throwsA(
      isA<BackupException>().having((e) => e.message, 'message', message),
    );
    Uint8List json(Object value) => utf8.encode(jsonEncode(value));
    BackupFile parse(Uint8List bytes) => parseBackup(bytes, schemaVersion: 1);

    test('JSON이 아니거나 다른 앱의 파일이면 거절한다', () {
      const message = '이 앱에서 만든 백업 파일이 아니에요';
      expect(
        () => parse(Uint8List.fromList([0xFF, 0xFE, 0x00])),
        fails(message),
      );
      expect(
        () => parse(utf8.encode('날짜,금액\n2026-11-01,1000')),
        fails(message),
      );
      expect(() => parse(json({'app': 'other', 'format': 1})), fails(message));
      expect(() => parse(json([1, 2, 3])), fails(message));
    });

    test('더 새 버전의 앱에서 만든 백업은 업데이트를 안내한다', () async {
      final bytes = await createBackup(source, settings: const {}, now: now);
      expect(
        () => parseBackup(bytes, schemaVersion: source.schemaVersion - 1),
        fails('더 새 버전의 앱에서 만든 백업이에요. 앱을 업데이트한 뒤 복원해주세요'),
      );
    });
  });

  group('손상된 백업은 복원하지 않고 지금 데이터를 그대로 둔다', () {
    Future<void> expectRejected(
      void Function(Map<String, List<Map<String, Object?>>> tables) damage,
    ) async {
      await fill(source);
      await addEntry(target, date: '2026-11-10', categoryId: 3, amount: 4500);
      final before = await target.exportAllTables();
      final backup = await roundTrip(source);
      damage(backup.tables);

      await expectLater(
        restoreRecords(target, backup),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            '백업 파일 내용이 손상돼서 복원할 수 없어요',
          ),
        ),
      );
      expect(await target.exportAllTables(), before);
    }

    test('없는 카테고리를 가리키는 내역', () {
      return expectRejected((t) => t['entries']!.first['category_id'] = 999);
    });

    test('필수 값이 빠진 행', () {
      return expectRejected((t) => t['entries']!.first.remove('amount'));
    });

    test('수입 카테고리가 하나도 없음', () {
      return expectRejected((t) {
        t['categories']!.removeWhere(
          (c) => c['kind'] == EntryKind.income.index,
        );
        t['entries']!.removeWhere((e) => e['kind'] == EntryKind.income.index);
      });
    });
  });

  group('설정', () {
    Future<(ProviderContainer, SharedPreferences)> open(
      Map<String, Object> values,
    ) async {
      SharedPreferences.setMockInitialValues(values);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return (container, prefs);
    }

    test('설정을 통째로 내보낸다(목록에 없는 설정 포함, 다른 저장값은 제외)', () async {
      final (container, _) = await open({
        'settings.onboardingDone': true,
        'settings.fontSize': 'large',
        'settings.someFutureOption': 3,
        'other.key': 'x',
      });
      expect(container.read(settingsProvider.notifier).exportValues(), {
        'onboardingDone': true,
        'fontSize': 'large',
        'someFutureOption': 3,
      });
    });

    test('복원하면 지금 설정을 백업 값으로 바꾸고, 온보딩은 끝낸 것으로 한다', () async {
      final (container, prefs) = await open({
        'settings.onboardingDone': false,
        'settings.exitConfirm': true,
        'other.key': 'x',
      });
      await container.read(settingsProvider.notifier).replaceWith({
        'mistapProtection': true,
        'budgetThreshold': 80,
        'someFutureOption': 'on',
        'broken': [1, 2], // 형식이 맞지 않는 값은 건너뛴다.
      });

      final s = container.read(settingsProvider);
      expect(s.onboardingDone, isTrue);
      expect(s.mistapProtection, isTrue);
      expect(s.budgetThreshold, 80);
      expect(s.exitConfirm, isFalse, reason: '백업에 없던 설정은 기본값');
      expect(prefs.getString('settings.someFutureOption'), 'on');
      expect(prefs.containsKey('settings.broken'), isFalse);
      expect(prefs.getString('other.key'), 'x', reason: '설정이 아닌 값은 건드리지 않는다');
    });
  });

  test('파일 이름에 만든 날짜와 시각이 들어간다', () {
    expect(backupFileName(now), 'gagyebu-backup-20261111-1030.json');
  });
}
