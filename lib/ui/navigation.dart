import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 하단 탭 순서.
enum AppTab { home, input, analysis, settings }

/// 지금 열려 있는 하단 탭. 다른 화면에서 탭을 바꿀 때도 쓴다(예: 홈 비율 막대 → 분석).
class AppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) => state = tab;
}

final appTabProvider = NotifierProvider<AppTabNotifier, AppTab>(
  AppTabNotifier.new,
);
