import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 하단 탭 순서.
enum AppTab { home, input, analysis, settings }

/// 지금 열려 있는 하단 탭. 다른 화면에서 탭을 바꿀 때도 쓴다(예: 홈 비율 막대 → 분석).
class AppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) {
    // 다른 탭에서 입력 탭으로 올 때마다 빈 입력 화면으로 새로 시작한다.
    if (tab == AppTab.input && state != AppTab.input) {
      ref.read(inputSessionProvider.notifier).next();
    }
    state = tab;
  }
}

final appTabProvider = NotifierProvider<AppTabNotifier, AppTab>(
  AppTabNotifier.new,
);

/// 입력 탭을 열 때마다 1씩 늘어나는 번호. 입력 화면의 key로 써서 상태를 새로 만든다.
class InputSessionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void next() => state++;
}

final inputSessionProvider = NotifierProvider<InputSessionNotifier, int>(
  InputSessionNotifier.new,
);
