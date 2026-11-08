import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FontStyleOption { system, gothic, soft }

enum FontSizeOption {
  small(15),
  medium(16),
  large(18);

  const FontSizeOption(this.px);

  /// 이전 앱의 루트 글자 크기(px). 16을 기준으로 글자 배율을 정한다.
  final int px;

  double get scale => px / 16;
}

/// 설정 화면에서 고르는 값들. 기본값은 모두 꺼짐/기본.
/// "내역 데이터 초기화"에서는 유지되고, "앱 전체 초기화"에서는 지워진다.
class AppSettings {
  const AppSettings({
    this.onboardingDone = false,
    this.autoCopyBudget = false,
    this.showHomeIncome = true,
    this.showAnalysisIncome = true,
    this.mistapProtection = false,
    this.exitConfirm = false,
    this.fontStyle = FontStyleOption.system,
    this.fontSize = FontSizeOption.medium,
    this.budgetThreshold = 100,
    this.highlightColor = 'red',
    this.totalHighlightInCategoryMode = false,
  });

  final bool onboardingDone;
  final bool autoCopyBudget;
  final bool showHomeIncome;
  final bool showAnalysisIncome;
  final bool mistapProtection;
  final bool exitConfirm;
  final FontStyleOption fontStyle;
  final FontSizeOption fontSize;

  /// 80 | 90 | 100 (몇 %에서 '초과'로 표시할지)
  final int budgetThreshold;
  final String highlightColor;
  final bool totalHighlightInCategoryMode;

  AppSettings copyWith({
    bool? onboardingDone,
    bool? autoCopyBudget,
    bool? showHomeIncome,
    bool? showAnalysisIncome,
    bool? mistapProtection,
    bool? exitConfirm,
    FontStyleOption? fontStyle,
    FontSizeOption? fontSize,
    int? budgetThreshold,
    String? highlightColor,
    bool? totalHighlightInCategoryMode,
  }) => AppSettings(
    onboardingDone: onboardingDone ?? this.onboardingDone,
    autoCopyBudget: autoCopyBudget ?? this.autoCopyBudget,
    showHomeIncome: showHomeIncome ?? this.showHomeIncome,
    showAnalysisIncome: showAnalysisIncome ?? this.showAnalysisIncome,
    mistapProtection: mistapProtection ?? this.mistapProtection,
    exitConfirm: exitConfirm ?? this.exitConfirm,
    fontStyle: fontStyle ?? this.fontStyle,
    fontSize: fontSize ?? this.fontSize,
    budgetThreshold: budgetThreshold ?? this.budgetThreshold,
    highlightColor: highlightColor ?? this.highlightColor,
    totalHighlightInCategoryMode:
        totalHighlightInCategoryMode ?? this.totalHighlightInCategoryMode,
  );

  Map<String, Object> toJson() => {
    'onboardingDone': onboardingDone,
    'autoCopyBudget': autoCopyBudget,
    'showHomeIncome': showHomeIncome,
    'showAnalysisIncome': showAnalysisIncome,
    'mistapProtection': mistapProtection,
    'exitConfirm': exitConfirm,
    'fontStyle': fontStyle.name,
    'fontSize': fontSize.name,
    'budgetThreshold': budgetThreshold,
    'highlightColor': highlightColor,
    'totalHighlightInCategoryMode': totalHighlightInCategoryMode,
  };

  /// 저장된 값이 없거나 형식이 맞지 않으면 기본값을 쓴다.
  factory AppSettings.fromPrefs(SharedPreferences p) {
    const d = AppSettings();
    T pick<T>(String key, T fallback) {
      final v = p.get('$_prefix$key');
      return v is T ? v : fallback;
    }

    E pickEnum<E extends Enum>(String key, List<E> values, E fallback) {
      final name = pick<String>(key, fallback.name);
      return values.firstWhere((e) => e.name == name, orElse: () => fallback);
    }

    return AppSettings(
      onboardingDone: pick('onboardingDone', d.onboardingDone),
      autoCopyBudget: pick('autoCopyBudget', d.autoCopyBudget),
      showHomeIncome: pick('showHomeIncome', d.showHomeIncome),
      showAnalysisIncome: pick('showAnalysisIncome', d.showAnalysisIncome),
      mistapProtection: pick('mistapProtection', d.mistapProtection),
      exitConfirm: pick('exitConfirm', d.exitConfirm),
      fontStyle: pickEnum('fontStyle', FontStyleOption.values, d.fontStyle),
      fontSize: pickEnum('fontSize', FontSizeOption.values, d.fontSize),
      budgetThreshold: pick('budgetThreshold', d.budgetThreshold),
      highlightColor: pick('highlightColor', d.highlightColor),
      totalHighlightInCategoryMode: pick(
        'totalHighlightInCategoryMode',
        d.totalHighlightInCategoryMode,
      ),
    );
  }

  static const _prefix = 'settings.';
}

/// main()에서 실제 인스턴스로 덮어쓴다.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('main()에서 덮어써야 해요'),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() =>
      AppSettings.fromPrefs(ref.read(sharedPreferencesProvider));

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    final p = ref.read(sharedPreferencesProvider);
    for (final MapEntry(:key, :value) in state.toJson().entries) {
      final k = '${AppSettings._prefix}$key';
      switch (value) {
        case bool v:
          await p.setBool(k, v);
        case int v:
          await p.setInt(k, v);
        case String v:
          await p.setString(k, v);
      }
    }
  }

  /// 앱 전체 초기화: 저장소를 통째로 비운다(항목을 나열하지 않는다).
  Future<void> clearAll() async {
    await ref.read(sharedPreferencesProvider).clear();
    state = const AppSettings();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
