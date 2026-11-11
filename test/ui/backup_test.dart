import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/backup.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'pump.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> openSettings(WidgetTester tester) => tap(
    tester,
    find.descendant(of: find.byType(NavigationBar), matching: find.text('설정')),
  );

  /// 다른 폰에서 만든 백업: 카페 내역 1건, 11월 총 예산 300,000원, 글자 크게.
  Future<Uint8List> otherPhoneBackup(WidgetTester tester) async {
    final bytes = await tester.runAsync(() async {
      final other = memoryDatabase();
      await addEntry(
        other,
        date: '2026-11-04',
        categoryId: 3,
        amount: 5500,
        description: '라떼',
      );
      await other.saveMonthBudget(
        const MonthBudget(
          monthKey: '2026-11',
          mode: BudgetMode.total,
          total: 300000,
        ),
      );
      final bytes = await createBackup(
        other,
        settings: {'onboardingDone': true, 'fontSize': 'large'},
        now: DateTime(2026, 11, 5, 9),
      );
      await other.close();
      return bytes;
    });
    return bytes!;
  }

  Future<void> withData(AppDatabase db) async {
    await addEntry(
      db,
      date: '2026-11-07',
      categoryId: 1,
      amount: 9000,
      description: '김밥',
    );
  }

  testWidgets('백업 파일 만들기: 날짜가 든 이름으로 기록과 설정을 저장한다', (tester) async {
    String? savedName;
    Uint8List? savedBytes;
    await pumpApp(
      tester,
      settings: {'mistapProtection': true},
      setup: withData,
      backupSaver: (name, bytes) async {
        savedName = name;
        savedBytes = bytes;
        return true;
      },
    );
    await openSettings(tester);
    await tap(tester, find.text('백업 파일 만들기'));

    expect(find.text('✓ 백업 파일을 저장했어요'), findsOneWidget);
    expect(savedName, 'gagyebu-backup-20261108-1000.json');
    final backup = parseBackup(savedBytes!, schemaVersion: 1);
    expect(backup.entryCount, 1);
    expect(backup.categoryCount, 8);
    expect(backup.settings['mistapProtection'], true);
    expect(
      utf8.decode(savedBytes!),
      isNot(contains('lock.')),
      reason: '잠금 정보 제외',
    );
  });

  testWidgets('백업에서 복원: 내용을 보여주고, 확인하면 기록과 설정이 백업으로 바뀐다', (tester) async {
    final file = await otherPhoneBackup(tester);
    final db = await pumpApp(tester, setup: withData, backupFile: file);
    expect(find.text('김밥'), findsOneWidget);

    await openSettings(tester);
    await tap(tester, find.text('백업에서 복원하기'));
    expect(find.text('백업에서 복원할까요?'), findsOneWidget);
    expect(
      find.textContaining('2026.11.05 09:00에 만든 백업이에요 · 내역 1건 · 카테고리 8개'),
      findsOneWidget,
    );
    await tap(tester, find.text('복원하기'));

    expect(find.text('✓ 백업에서 복원했어요'), findsOneWidget);
    expect(find.text('11월 지출'), findsOneWidget, reason: '홈으로 돌아옴');
    expect(find.text('라떼'), findsOneWidget);
    expect(find.text('김밥'), findsNothing);
    final nov = await tester.runAsync(() => db.getMonthBudget('2026-11'));
    expect(nov!.totalBudget, 300000);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.fontSize'), 'large');
  });

  testWidgets('확인창에서 취소하면 아무것도 바꾸지 않는다', (tester) async {
    final file = await otherPhoneBackup(tester);
    final db = await pumpApp(tester, setup: withData, backupFile: file);
    await openSettings(tester);
    await tap(tester, find.text('백업에서 복원하기'));
    await tap(tester, find.text('취소'));

    final entries = await tester.runAsync(() => db.select(db.entries).get());
    expect(entries!.map((e) => e.description), ['김밥']);
  });

  testWidgets('이 앱의 백업이 아닌 파일은 이유를 알려주고 아무것도 바꾸지 않는다', (tester) async {
    final db = await pumpApp(
      tester,
      setup: withData,
      backupFile: utf8.encode('날짜,금액\n2026-11-01,1000'),
    );
    await openSettings(tester);
    await tap(tester, find.text('백업에서 복원하기'));

    expect(find.text('이 앱에서 만든 백업 파일이 아니에요'), findsOneWidget);
    expect(find.text('백업에서 복원할까요?'), findsNothing);
    final entries = await tester.runAsync(() => db.select(db.entries).get());
    expect(entries, hasLength(1));
  });

  testWidgets('새 폰: 온보딩 첫 화면에서 복원하면 온보딩 없이 홈으로 간다', (tester) async {
    final file = await otherPhoneBackup(tester);
    await pumpApp(tester, onboardingDone: false, backupFile: file);
    expect(find.text('가계부에 오신 걸 환영해요'), findsOneWidget);

    await tap(tester, find.text('백업 파일이 있나요? 백업에서 복원하기 ›'));
    await tap(tester, find.text('복원하기'));

    expect(find.text('가계부에 오신 걸 환영해요'), findsNothing);
    expect(find.text('라떼'), findsOneWidget);
    expect(find.text('총 300,000원'), findsOneWidget);
  });

  group('백업하고 초기화', () {
    Future<void> startReset(WidgetTester tester) async {
      await openSettings(tester);
      await tap(tester, find.text('데이터 초기화'));
      await tap(tester, find.text('내역 데이터 초기화'));
      await tap(tester, find.text('백업하고 초기화'));
    }

    testWidgets('백업 파일을 저장한 뒤 초기화한다', (tester) async {
      Uint8List? saved;
      final db = await pumpApp(
        tester,
        setup: withData,
        backupSaver: (_, bytes) async {
          saved = bytes;
          return true;
        },
      );
      await startReset(tester);

      expect(parseBackup(saved!, schemaVersion: 1).entryCount, 1);
      expect(find.text('가계부에 오신 걸 환영해요'), findsOneWidget);
      final entries = await tester.runAsync(() => db.select(db.entries).get());
      expect(entries, isEmpty);
    });

    testWidgets('백업 저장을 취소하면 초기화하지 않는다', (tester) async {
      final db = await pumpApp(tester, setup: withData);
      await startReset(tester);

      expect(find.text('백업을 저장하지 않아서 초기화하지 않았어요'), findsOneWidget);
      expect(find.text('가계부에 오신 걸 환영해요'), findsNothing);
      final entries = await tester.runAsync(() => db.select(db.entries).get());
      expect(entries, hasLength(1));
    });
  });
}
