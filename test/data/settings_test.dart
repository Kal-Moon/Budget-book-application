import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  test('저장된 값을 읽고, 없거나 형식이 틀린 값은 기본값으로', () async {
    final (container, _) = await open({
      'settings.budgetThreshold': 80,
      'settings.fontSize': 'large',
      'settings.exitConfirm': 'yes', // 형식이 틀림
      'settings.fontStyle': 'unknown', // 없는 선택지
    });
    final s = container.read(settingsProvider);
    expect(s.budgetThreshold, 80);
    expect(s.fontSize, FontSizeOption.large);
    expect(s.exitConfirm, isFalse);
    expect(s.fontStyle, FontStyleOption.system);
    expect(s.onboardingDone, isFalse);
  });

  // 회귀 테스트: 이전 앱은 초기화할 항목을 손으로 나열해서, 나중에 추가한 설정이
  // 초기화에서 빠졌다. 앱 전체 초기화는 저장소를 통째로 비운다.
  test('앱 전체 초기화: 목록에 없는(나중에 추가될) 설정까지 모두 지운다', () async {
    final (container, prefs) = await open({
      'settings.onboardingDone': true,
      'settings.mistapProtection': true,
      'settings.budgetThreshold': 90,
      'settings.someFutureOption': 'on',
      'other.key': 1,
    });
    await container.read(settingsProvider.notifier).clearAll();

    expect(prefs.getKeys(), isEmpty);
    final s = container.read(settingsProvider);
    expect(s.onboardingDone, isFalse);
    expect(s.mistapProtection, isFalse);
    expect(s.budgetThreshold, 100);
  });

  test('설정 하나를 바꿔도 다른 설정(나중에 추가될 것 포함)은 그대로 남는다', () async {
    final (container, prefs) = await open({
      'settings.onboardingDone': true,
      'settings.mistapProtection': true,
      'settings.someFutureOption': 'on',
    });
    // "내역 데이터 초기화"가 하는 것: 온보딩만 다시, 설정은 유지.
    await container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(onboardingDone: false));

    expect(prefs.getBool('settings.onboardingDone'), isFalse);
    expect(prefs.getBool('settings.mistapProtection'), isTrue);
    expect(prefs.getString('settings.someFutureOption'), 'on');
  });
}
