import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/today.dart';
import '../data/providers.dart';
import '../data/settings.dart';
import 'budget/budget_sheet.dart';
import 'navigation.dart';
import 'screens/analysis_screen.dart';
import 'screens/home_screen.dart';
import 'screens/input_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/confirm_sheet.dart';

/// 하단 탭 4개(홈/입력/분석/설정). 탭을 오가도 각 화면 상태가 유지된다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _screens = [
    HomeScreen(),
    InputScreen(),
    AnalysisScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNewMonth());
  }

  /// 새 달이 되면(앱을 켰을 때 포함) 이번 달 예산을 이어받을지 확인한다.
  Future<void> _checkNewMonth() async {
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    final monthKey = ref.read(currentMonthKeyProvider);
    await handleNewMonthBudget(
      context,
      db: ref.read(databaseProvider),
      monthKey: monthKey,
      autoCopy: settings.autoCopyBudget,
      promptedMonth: settings.budgetPromptMonth,
      markPrompted: () => ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(budgetPromptMonth: monthKey)),
    );
  }

  /// 뒤로가기: 다른 탭이면 홈으로, 홈이면 (설정에 따라 확인 후) 종료.
  /// 입력 탭은 입력 화면이 직접 처리한다(취소 확인).
  Future<void> _onBack() async {
    final tab = ref.read(appTabProvider);
    if (tab == AppTab.input) return;
    if (tab != AppTab.home) {
      ref.read(appTabProvider.notifier).select(AppTab.home);
      return;
    }
    final ok = await showConfirmSheet(
      context,
      title: '앱을 종료할까요?',
      description: const Text('가계부를 종료해요. 입력했던 내용은 이미 저장돼 있어서 그대로 남아있어요.'),
      confirmLabel: '종료하기',
    );
    if (ok) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(appTabProvider);
    final exitConfirm = ref.watch(
      settingsProvider.select((s) => s.exitConfirm),
    );
    ref.listen(currentMonthKeyProvider, (_, _) => _checkNewMonth());
    return PopScope(
      canPop: tab == AppTab.home && !exitConfirm,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: IndexedStack(index: tab.index, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: (i) =>
              ref.read(appTabProvider.notifier).select(AppTab.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: '입력',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: '분석',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
