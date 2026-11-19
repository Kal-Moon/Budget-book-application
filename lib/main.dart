import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/today.dart';
import 'data/settings.dart';
import 'ui/app_shell.dart';
import 'ui/lock/lock_controller.dart';
import 'ui/lock/lock_screen.dart';
import 'ui/lock/locked_back_blocker.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  // 잠긴 동안 뒤로가기가 잠금 화면 아래의 화면을 닫지 못하게, 앱보다 먼저 등록한다.
  WidgetsBinding.instance.addObserver(
    LockedBackBlocker(() => container.read(lockProvider).locked),
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const GagyebuApp()),
  );
}

class GagyebuApp extends ConsumerWidget {
  const GagyebuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(settingsProvider.select((s) => s.fontSize));
    final onboardingDone = ref.watch(
      settingsProvider.select((s) => s.onboardingDone),
    );
    return MaterialApp(
      title: '가계부',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // 글자 크기 설정: 레이아웃은 그대로 두고 글자만 키우고 줄인다.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) * fontSize.scale,
          ),
        ),
        child: LockGate(child: DateWatcher(child: child!)),
      ),
      home: onboardingDone ? const AppShell() : const OnboardingScreen(),
    );
  }
}
