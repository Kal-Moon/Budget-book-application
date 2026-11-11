import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ui/lock/pin_pad.dart';
import 'package:gagyebu/ui/settings/settings_widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'pump.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(
        find.descendant(of: find.byType(PinPad), matching: find.text(d)).last,
      );
      await tester.pump();
    }
    await settle(tester);
  }

  Finder lockToggle() => find.descendant(
    of: find.widgetWithText(SettingsToggle, 'PIN으로 잠그기'),
    matching: find.byType(Switch),
  );

  Future<void> openDetailSettings(WidgetTester tester) async {
    await tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('설정'),
      ),
    );
    await tap(tester, find.text('세부 설정'));
    // 앱 잠금은 목록 맨 아래에 있다.
    await tester.dragUntilVisible(
      find.text('PIN으로 잠그기'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await settle(tester);
  }

  /// 앱을 백그라운드로 보냈다가 [away] 뒤에 다시 연다.
  Future<void> leaveAndReturn(
    WidgetTester tester,
    FakeClock clock,
    Duration away,
  ) async {
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    clock.current = clock.current.add(away);
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await settle(tester);
  }

  group('잠금 켜기', () {
    testWidgets('복구 방법 없이 켜면 경고하고, 그래도 켤 수 있다', (tester) async {
      final store = MemorySecretStore();
      await pumpApp(tester, secrets: store);
      await openDetailSettings(tester);
      await tap(tester, lockToggle());

      expect(find.text('새 PIN을 설정해주세요'), findsOneWidget);
      await enterPin(tester, '4821');
      expect(find.text('한 번 더 입력해주세요'), findsOneWidget);
      await enterPin(tester, '4821');

      expect(find.text('PIN을 잊었을 때 어떻게 확인할까요?'), findsOneWidget);
      expect(find.textContaining('등록된 지문·얼굴이 없어서'), findsOneWidget);
      await tap(tester, find.text('잠금 켜기'));
      expect(find.text('복구 방법 없이 켤까요?'), findsOneWidget);
      expect(store.values, isEmpty, reason: '아직 켜지지 않음');
      await tap(tester, find.text('그래도 켜기'));

      expect(find.text('✓ 앱 잠금이 설정됐어요'), findsOneWidget);
      expect(find.text('PIN 바꾸기'), findsOneWidget);
      expect(find.text('정하지 않음 ›'), findsOneWidget);
      expect(store.values.containsKey('lock.pinHash'), isTrue);
      expect(store.values.values.any((v) => v.contains('4821')), isFalse);
    });

    testWidgets('두 번 입력한 PIN이 다르면 처음부터 다시', (tester) async {
      await pumpApp(tester);
      await openDetailSettings(tester);
      await tap(tester, lockToggle());
      await enterPin(tester, '1111');
      await enterPin(tester, '2222');
      expect(find.textContaining('입력한 번호가 서로 달라요'), findsOneWidget);
      expect(find.text('새 PIN을 설정해주세요'), findsOneWidget);
    });

    testWidgets('질문과 지문을 함께 고를 수 있고, 지문은 켜기 전에 한 번 확인한다', (tester) async {
      final store = MemorySecretStore();
      final bio = FakeBiometricAuth(available: true, succeeds: true);
      await pumpApp(tester, secrets: store, biometric: bio);
      await openDetailSettings(tester);
      await tap(tester, lockToggle());
      await enterPin(tester, '4821');
      await enterPin(tester, '4821');

      await tap(tester, find.byKey(const ValueKey('recovery-지문·얼굴 인식')));
      await tap(tester, find.byKey(const ValueKey('recovery-비밀번호 찾기 질문')));
      await tap(tester, find.text('잠금 켜기'));
      expect(find.text('질문과 답을 모두 입력해주세요.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '질문'),
        '첫 반려동물 이름은?',
      );
      await tester.enterText(find.widgetWithText(TextField, '답'), '초코');
      await settle(tester);
      await tap(tester, find.text('잠금 켜기'));

      expect(bio.prompts, 1);
      expect(find.text('지문·얼굴 + 질문 ›'), findsOneWidget);
      expect(store.values['lock.question'], '첫 반려동물 이름은?');
      expect(store.values['lock.biometric'], '1');
      expect(store.values.values.any((v) => v.contains('초코')), isFalse);
    });
  });

  group('잠금 화면', () {
    testWidgets('앱을 켜면 잠겨 있고, 틀린 PIN은 거절, 맞는 PIN으로 열린다', (tester) async {
      await pumpApp(tester, secrets: lockedStore());
      expect(find.text('PIN을 입력해주세요'), findsOneWidget);
      expect(find.text('지문·얼굴로 열기'), findsNothing);

      await enterPin(tester, '0000');
      expect(find.text('번호가 올바르지 않아요.'), findsOneWidget);
      await enterPin(tester, '1234');
      expect(find.text('PIN을 입력해주세요'), findsNothing);
      expect(find.text('11월 지출'), findsOneWidget);
    });

    testWidgets('잠겨 있는 동안 뒤로가기는 무시하고, 열린 뒤에는 평소대로 동작한다', (tester) async {
      await pumpApp(
        tester,
        settings: {'exitConfirm': true},
        secrets: lockedStore(),
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('PIN을 입력해주세요'), findsOneWidget);
      expect(find.text('앱을 종료할까요?'), findsNothing);

      await enterPin(tester, '1234');
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('앱을 종료할까요?'), findsOneWidget);
    });

    testWidgets('지문·얼굴을 켜 뒀으면 인식 창이 먼저 뜨고, 성공하면 바로 열린다', (tester) async {
      final bio = FakeBiometricAuth(available: true, succeeds: true);
      await pumpApp(
        tester,
        secrets: lockedStore(biometric: true),
        biometric: bio,
      );
      expect(bio.prompts, 1);
      expect(find.text('PIN을 입력해주세요'), findsNothing);
    });

    testWidgets('지문·얼굴 인식을 취소하면 PIN 입력으로 남는다', (tester) async {
      final bio = FakeBiometricAuth(available: true);
      await pumpApp(
        tester,
        secrets: lockedStore(biometric: true),
        biometric: bio,
      );
      expect(find.text('PIN을 입력해주세요'), findsOneWidget);
      expect(find.text('지문·얼굴로 열기'), findsOneWidget);
    });

    testWidgets('1분 넘게 떠나 있다 돌아오면 다시 잠긴다', (tester) async {
      final clock = FakeClock(DateTime(2026, 11, 8, 10));
      await pumpApp(tester, secrets: lockedStore(), clock: clock);
      await enterPin(tester, '1234');
      expect(find.text('PIN을 입력해주세요'), findsNothing);

      await leaveAndReturn(tester, clock, const Duration(seconds: 30));
      expect(find.text('PIN을 입력해주세요'), findsNothing, reason: '잠깐 다녀옴');

      await leaveAndReturn(tester, clock, const Duration(minutes: 2));
      expect(find.text('PIN을 입력해주세요'), findsOneWidget);
    });
  });

  group('PIN을 잊었을 때', () {
    testWidgets('질문에 맞게 답하면 새 PIN을 정하고, 데이터는 그대로다', (tester) async {
      final store = lockedStore(question: '첫 반려동물 이름은?', answer: '초코');
      final db = await pumpApp(
        tester,
        secrets: store,
        setup: (db) =>
            addEntry(db, date: '2026-11-07', categoryId: 3, amount: 4500),
      );
      await tap(tester, find.text('PIN을 잊었어요'));
      expect(find.text('지문·얼굴 인식으로 확인'), findsNothing);
      await tap(tester, find.text('질문에 답하기'));
      expect(find.text('첫 반려동물 이름은?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '모름');
      await tap(tester, find.text('확인'));
      expect(find.text('답이 달라요. 4번 더 시도할 수 있어요.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), ' 초 코 ');
      await tap(tester, find.text('확인'));
      expect(find.text('새 PIN을 설정해주세요'), findsOneWidget);
      await enterPin(tester, '9090');
      await enterPin(tester, '9090');

      expect(find.text('11월 지출'), findsOneWidget);
      expect(
        store.values['lock.pinHash'],
        isNot(lockedStore().values['lock.pinHash']),
      );
      final entries = await tester.runAsync(() => db.select(db.entries).get());
      expect(entries, hasLength(1));
    });

    testWidgets('지문·얼굴 인식으로 확인해도 새 PIN을 정할 수 있다', (tester) async {
      final bio = FakeBiometricAuth(available: true);
      await pumpApp(
        tester,
        secrets: lockedStore(biometric: true),
        biometric: bio,
      );
      await tap(tester, find.text('PIN을 잊었어요'));
      await tap(tester, find.text('지문·얼굴 인식으로 확인'));
      expect(find.textContaining('확인하지 못했어요'), findsOneWidget);

      bio.succeeds = true;
      await tap(tester, find.text('지문·얼굴 인식으로 확인'));
      expect(find.text('새 PIN을 설정해주세요'), findsOneWidget);
    });

    testWidgets('복구 방법이 없으면 앱 전체 초기화만 할 수 있다', (tester) async {
      final store = lockedStore();
      final db = await pumpApp(
        tester,
        secrets: store,
        settings: {'fontSize': 'large'},
        setup: (db) =>
            addEntry(db, date: '2026-11-07', categoryId: 3, amount: 4500),
      );
      await tap(tester, find.text('PIN을 잊었어요'));
      expect(find.textContaining('복구 방법을 정해두지 않아서'), findsOneWidget);
      expect(find.text('질문에 답하기'), findsNothing);
      await tap(tester, find.text('앱 전체 초기화'));
      expect(find.text('이 작업은 되돌릴 수 없어요.'), findsOneWidget);
      await tap(tester, find.text('모두 지우고 초기화하기'));

      expect(find.text('가계부에 오신 걸 환영해요'), findsOneWidget);
      expect(store.values, isEmpty);
      final entries = await tester.runAsync(() => db.select(db.entries).get());
      expect(entries, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('잠금 설정 바꾸기', () {
    testWidgets('잠금을 끄려면 현재 PIN이 필요하다', (tester) async {
      final store = lockedStore();
      await pumpApp(tester, secrets: store);
      await enterPin(tester, '1234');
      await openDetailSettings(tester);

      await tap(tester, lockToggle());
      expect(find.text('현재 PIN을 입력해주세요'), findsOneWidget);
      await enterPin(tester, '0000');
      expect(find.text('번호가 올바르지 않아요.'), findsOneWidget);
      expect(store.values, isNotEmpty);

      await enterPin(tester, '1234');
      expect(find.text('앱 잠금을 껐어요'), findsOneWidget);
      expect(store.values, isEmpty);
      expect(find.text('PIN 바꾸기'), findsNothing);
    });

    testWidgets('앱 전체 초기화는 잠금도 지우고, 내역 데이터 초기화는 잠금을 남긴다', (tester) async {
      final store = lockedStore();
      await pumpApp(tester, secrets: store);
      await enterPin(tester, '1234');
      await tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('설정'),
        ),
      );
      await tap(tester, find.text('데이터 초기화'));
      await tap(tester, find.text('내역 데이터 초기화'));
      await tap(tester, find.text('백업 없이 초기화'));
      expect(store.values, isNotEmpty, reason: '설정은 유지');
    });
  });
}
