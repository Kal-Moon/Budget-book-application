import 'package:flutter/material.dart';

import '../domain/analysis.dart';

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
    this.incomeBorder = const Color(0xFFA9CB8A),
    this.accentStrong = const Color(0xFF185FA5),
    this.dangerStrong = const Color(0xFFA32D2D),
    this.warningBg = const Color(0xFFFAEEDA),
    this.warningText = const Color(0xFF854F0B),
    this.onAccent = const Color(0xFFFFFFFF),
  });

  /// 어두운 화면용. 밝은 색의 역할을 그대로 두고 밝기만 뒤집었다.
  const AppColors.dark()
    : surface0 = const Color(0xFF1A1A18),
      surface1 = const Color(0xFF222220),
      surface2 = const Color(0xFF2B2A27),
      border = const Color(0xFF3A3934),
      borderStrong = const Color(0xFF55534C),
      textPrimary = const Color(0xFFEDECE7),
      textSecondary = const Color(0xFFB5B3AB),
      textMuted = const Color(0xFF8A887F),
      accent = const Color(0xFF5AA2EC),
      accentBg = const Color(0xFF1E3246),
      danger = const Color(0xFFEF6766),
      dangerBg = const Color(0xFF3D2323),
      income = const Color(0xFF8BC25A),
      incomeBg = const Color(0xFF263220),
      incomeBorder = const Color(0xFF4C6B33),
      accentStrong = const Color(0xFF8DC0F4),
      dangerStrong = const Color(0xFFF49A99),
      warningBg = const Color(0xFF3B2F18),
      warningText = const Color(0xFFE8B865),
      onAccent = const Color(0xFFFFFFFF);

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

  /// 수입 내역 칸의 테두리.
  final Color incomeBorder;

  /// 진한 파랑: 차액이 남을 때, "○월 데이터를 보는 중" 안내.
  final Color accentStrong;

  /// 진한 빨강: 경고·오류 문구.
  final Color dangerStrong;

  /// 노란 안내 배너(예산 미설정)의 배경과 글자.
  final Color warningBg;
  final Color warningText;

  /// 강조색(파랑·빨강) 배경 위의 글자.
  final Color onAccent;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final c = brightness == Brightness.dark
      ? const AppColors.dark()
      : const AppColors();
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
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
    dialogTheme: DialogThemeData(backgroundColor: c.surface0),
    // 모든 시트: 손잡이 표시, 화면 배경색(시트마다 따로 정하지 않는다).
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: c.surface0,
      modalBackgroundColor: c.surface0,
    ),
    extensions: [c],
  );
}

/// 분석 화면 강조색을 지금 화면 밝기에 맞춘 것.
/// 밝은 화면은 세부 설정의 색 그대로, 어두운 화면은 진한 배경 위에서 읽히게 바꾼다.
class HighlightPalette {
  const HighlightPalette({
    required this.background,
    required this.border,
    required this.text,
    required this.badge,
    required this.onBadge,
  });

  final Color background;
  final Color border;
  final Color text;

  /// "초과" 표시의 배경과 글자.
  final Color badge;
  final Color onBadge;
}

extension HighlightPaletteX on BuildContext {
  HighlightPalette highlightOf(HighlightColor h) {
    if (Theme.of(this).brightness == Brightness.dark) {
      final border = Color(h.border);
      return HighlightPalette(
        background: border.withValues(alpha: 0.18),
        border: border,
        text: Color.lerp(border, const Color(0xFFFFFFFF), 0.45)!,
        badge: border,
        onBadge: colors.surface0,
      );
    }
    return HighlightPalette(
      background: Color(h.background),
      border: Color(h.border),
      text: Color(h.text),
      badge: Color(h.text),
      onBadge: colors.onAccent,
    );
  }
}
