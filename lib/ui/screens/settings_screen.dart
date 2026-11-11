import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/today.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/budget.dart';
import '../budget/budget_sheet.dart';
import '../categories/category_manage_screen.dart';
import '../import/import_screen.dart';
import '../settings/backup_flow.dart';
import '../settings/detail_settings_screen.dart';
import '../settings/reset_flow.dart';
import '../settings/settings_widgets.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';

final _versionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final version = ref.watch(_versionProvider).value ?? '—';
    final expenseCount =
        ref.watch(categoriesProvider(EntryKind.expense)).value?.length ?? 0;
    final incomeCount =
        ref.watch(categoriesProvider(EntryKind.income)).value?.length ?? 0;
    final budget = ref
        .watch(monthBudgetProvider(ref.watch(currentMonthKeyProvider)))
        .value;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          SettingsSection(
            title: '예산',
            children: [
              SettingsRow(
                label: '예산 설정 바꾸기',
                value: budget == null
                    ? null
                    : budget.isSet
                    ? budget.mode.label
                    : '아직 정하지 않음',
                onTap: () => showBudgetSheet(context),
              ),
              SettingsToggle(
                label: '지난달 예산 자동 적용',
                description: '새 달이 되면 지난달 예산을 자동으로 이어받아요',
                value: s.autoCopyBudget,
                onChanged: (v) {
                  notifier.update((s) => s.copyWith(autoCopyBudget: v));
                  showToast(
                    context,
                    v ? '다음 달부터 자동으로 예산이 이어져요' : '다음 달엔 다시 물어볼게요',
                  );
                },
              ),
            ],
          ),
          SettingsSection(
            title: '카테고리',
            children: [
              SettingsRow(
                label: '카테고리 관리',
                value: '지출 $expenseCount개 · 수입 $incomeCount개',
                onTap: () => openCategoryManage(context),
              ),
            ],
          ),
          SettingsSection(
            title: '수입·지출 요약 표시',
            children: [
              SettingsToggle(
                label: '홈 화면에 표시',
                description: '홈 화면에 이번 달 수입·지출·차액을 보여줘요',
                value: s.showHomeIncome,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(showHomeIncome: v)),
              ),
              SettingsToggle(
                label: '분석 화면에 표시',
                description: '분석 화면에도 수입·지출·차액을 보여줘요',
                value: s.showAnalysisIncome,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(showAnalysisIncome: v)),
              ),
            ],
          ),
          SettingsSection(
            title: '더 깊은 커스터마이징',
            children: [
              SettingsRow(
                label: '세부 설정',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DetailSettingsScreen(),
                  ),
                ),
              ),
              const SettingsNote(
                '실수 방지, 글자 크기, 예산 알림 기준처럼 취향에 맞게 더 깊이 조정하고 싶을 때 '
                '들어가는 공간이에요. 기본값 그대로 써도 전혀 문제없어요.',
              ),
            ],
          ),
          SettingsSection(
            title: '데이터',
            children: [
              SettingsRow(
                label: '백업 파일 만들기',
                onTap: () => saveBackup(context, ref),
              ),
              SettingsRow(
                label: '백업에서 복원하기',
                onTap: () => startRestoreFlow(context, ref),
              ),
              const SettingsNote(
                '앱을 지우거나 폰을 바꾸면 데이터도 함께 사라져요. 백업 파일을 다운로드 폴더나 '
                '구글 드라이브에 저장해 두면 새 폰에서도 복원할 수 있어요. '
                '앱 잠금(PIN)은 백업에 들어가지 않아요.',
              ),
              SettingsRow(
                label: '다른 가계부에서 가져오기',
                onTap: () => openImport(context),
              ),
              const SettingsNote(
                '쓰던 가계부 앱에서 내보내기 한 엑셀(.xlsx) 또는 CSV 파일을 올리면 읽어와요.',
              ),
              SettingsRow(
                label: '데이터 초기화',
                danger: true,
                onTap: () => startResetFlow(context, ref),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '가계부 · ver.$version · 데이터는 이 기기에 저장돼요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
