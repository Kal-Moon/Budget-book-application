import 'package:flutter/material.dart';

/// 이전 앱(reference/index.html)의 :root 색상을 그대로 옮긴 값.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    this.surface0 = const Color(0xFFFFFFFF),
    this.surface1 = const Color(0xFFF7F7F5),
    this.surface2 = const Color(0xFFF0EFE9),
    this.border = const Color(0xFFE2E0D8),
    this.borderStrong = const Color(0xFFC9C6BA),
    this.textPrimary = const Color(0xFF1B1A17),
    this.textSecondary = const Color(0xFF63615A),
    this.textMuted = const Color(0xFF9A978C),
    this.accent = const Color(0xFF378ADD),
    this.accentBg = const Color(0xFFE6F1FB),
    this.danger = const Color(0xFFE24B4A),
    this.dangerBg = const Color(0xFFFCEBEB),
    this.income = const Color(0xFF3B6D11),
    this.incomeBg = const Color(0xFFEAF3DE),
  });

  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentBg;
  final Color danger;
  final Color dangerBg;
  final Color income;
  final Color incomeBg;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => this;
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme() {
  const c = AppColors();
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      primary: c.accent,
      error: c.danger,
      surface: c.surface0,
    ),
    scaffoldBackgroundColor: c.surface0,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface1,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface1,
      indicatorColor: c.accentBg,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, color: c.textSecondary),
      ),
    ),
    dividerColor: c.border,
    extensions: const [c],
  );
}
