import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/today.dart';
import 'data/settings.dart';
import 'ui/app_shell.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const GagyebuApp(),
    ),
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
        child: DateWatcher(child: child!),
      ),
      home: onboardingDone ? const AppShell() : const OnboardingScreen(),
    );
  }
}
