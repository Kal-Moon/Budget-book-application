import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/data/providers.dart';
import 'package:gagyebu/data/settings.dart';
import 'package:gagyebu/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// DB 스트림이 값을 내놓을 때까지 실제 시간을 조금 흘려보낸 뒤 화면을 그린다.
/// (drift는 실제 비동기 I/O를 써서 pumpAndSettle의 가짜 시간에서는 멈춘다)
/// 시트·화면 전환 애니메이션이 끝나도록 가짜 시간도 함께 흘려보낸다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
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
  Future<void> Function(AppDatabase db)? setup,
}) async {
  SharedPreferences.setMockInitialValues({
    'settings.onboardingDone': onboardingDone,
  });
  PackageInfo.setMockInitialValues(
    appName: '가계부',
    packageName: 'com.mybudgetapp.gagyebu',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  final prefs = await SharedPreferences.getInstance();
  final db = memoryDatabase();
  addTearDown(db.close);
  if (setup != null) await tester.runAsync(() => setup(db));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 8, 10))),
      ],
      child: const GagyebuApp(),
    ),
  );
  await settle(tester);
  return db;
}
