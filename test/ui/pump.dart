import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/data/lock_store.dart';
import 'package:gagyebu/data/providers.dart';
import 'package:gagyebu/data/receipt_scanner.dart';
import 'package:gagyebu/data/settings.dart';
import 'package:gagyebu/domain/receipt.dart';
import 'package:gagyebu/main.dart';
import 'package:gagyebu/ui/import/import_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// DB 스트림이 값을 내놓을 때까지 실제 시간을 조금 흘려보낸 뒤 화면을 그린다.
/// (drift는 실제 비동기 I/O를 써서 pumpAndSettle의 가짜 시간에서는 멈춘다)
/// 시트·화면 전환 애니메이션이 끝나도록 가짜 시간도 함께 흘려보낸다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// 메모리 DB와 가짜 시계(2026-11-08 10:00)로 앱을 띄운다.
/// [setup]은 화면을 띄우기 전에 DB를 준비할 때 쓴다.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  bool onboardingDone = true,
  Map<String, Object> settings = const {},
  Future<void> Function(AppDatabase db)? setup,
  PickedImportFile? importFile,
  List<String>? receiptRows,
  MemorySecretStore? secrets,
  FakeBiometricAuth? biometric,
  FakeClock? clock,
}) async {
  SharedPreferences.setMockInitialValues({
    'settings.onboardingDone': onboardingDone,
    for (final MapEntry(:key, :value) in settings.entries)
      'settings.$key': value,
  });
  PackageInfo.setMockInitialValues(
    appName: '가계부',
    packageName: 'com.mybudgetapp.gagyebu',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  // 세로로 긴 폰 화면(390×1200)으로 띄워서 목록 아래쪽까지 그려지게 한다.
  tester.view.physicalSize = const Size(1170, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final prefs = await SharedPreferences.getInstance();
  final db = memoryDatabase();
  // 화면을 먼저 내려서 DB 스트림 구독을 끊고, DB는 실제 시간(runAsync)에서 닫는다.
  // 가짜 시간에서 닫으면 남은 쿼리를 기다리다 테스트가 끝나지 않는다.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  if (setup != null) await tester.runAsync(() => setup(db));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(
          clock ?? FakeClock(DateTime(2026, 11, 8, 10)),
        ),
        // 잠금 정보는 메모리에, 지문·얼굴 인식은 가짜로(기본: 잠금 없음, 인식 불가).
        secretStoreProvider.overrideWithValue(secrets ?? MemorySecretStore()),
        biometricAuthProvider.overrideWithValue(
          biometric ?? FakeBiometricAuth(),
        ),
        // 가져오기에서 "파일 선택"을 누르면 이 파일을 고른 것으로 한다.
        importFilePickerProvider.overrideWithValue(() async => importFile),
        // 영수증 사진을 고르면 이 글자들(한 줄씩 위에서 아래로)을 읽은 것으로 한다.
        receiptScannerProvider.overrideWithValue(
          (_) async => receiptRows == null
              ? null
              : [
                  for (final (i, row) in receiptRows.indexed)
                    OcrLine(row, 10, i * 30.0, 300, i * 30.0 + 20),
                ],
        ),
      ],
      child: const GagyebuApp(),
    ),
  );
  await settle(tester);
  return db;
}
