import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings.dart';
import '../analysis/analysis_view.dart';
import '../home/home_view.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';

enum _ResetKind { records, everything }

/// 데이터 초기화: 선택창 → 최종 확인창(실수 방지 설정과 무관하게 항상) → 실행 → 온보딩부터.
Future<void> startResetFlow(BuildContext context, WidgetRef ref) async {
  final c = context.colors;
  final kind = await showModalBottomSheet<_ResetKind>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: c.surface0,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '무엇을 초기화할까요?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _ResetOption(
              title: '내역 데이터 초기화',
              description:
                  '지출·수입 내역, 카테고리, 예산을 지워요.\n'
                  '설정 화면에서 고른 값(글자 크기, 실수 방지 등)은 그대로 둬요.',
              onTap: () => Navigator.pop(context, _ResetKind.records),
            ),
            _ResetOption(
              title: '앱 전체 초기화',
              description: '모든 기록과 설정을 지우고, 앱을 막 설치한 상태로 되돌려요.',
              onTap: () => Navigator.pop(context, _ResetKind.everything),
            ),
          ],
        ),
      ),
    ),
  );
  if (kind == null || !context.mounted) return;

  final everything = kind == _ResetKind.everything;
  final ok = await showConfirmSheet(
    context,
    title: everything ? '앱 전체를 초기화할까요?' : '내역 데이터를 초기화할까요?',
    description: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: everything
                ? '지출·수입 내역, 카테고리, 예산과 모든 설정이 사라지고 처음 상태로 돌아가요.\n'
                : '지출·수입 내역, 카테고리, 예산이 모두 사라져요. 설정은 그대로 남아요.\n',
          ),
          TextSpan(
            text: '이 작업은 되돌릴 수 없어요.',
            style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
    confirmLabel: '초기화하기',
    destructive: true,
  );
  if (!ok || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final settings = ref.read(settingsProvider.notifier);
  final container = ProviderScope.containerOf(context);
  // 기록은 통째로 비우고 기본 카테고리만 다시 넣는다(항목을 나열하지 않는다).
  await ref.read(databaseProvider).clearRecords();
  // 화면 상태(보던 탭·달·필터)도 처음으로.
  container.invalidate(homeViewProvider);
  container.invalidate(analysisViewProvider);
  container.read(appTabProvider.notifier).select(AppTab.home);
  if (everything) {
    await settings.clearAll();
  } else {
    // 온보딩부터 다시 시작한다. 새 달 예산 팝업 기록도 기록에 딸린 값이라 지운다.
    await settings.update(
      (s) => s.copyWith(onboardingDone: false, budgetPromptMonth: ''),
    );
  }
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        everything ? '앱을 처음 상태로 되돌렸어요' : '내역 데이터가 초기화됐어요',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _ResetOption extends StatelessWidget {
  const _ResetOption({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: c.surface2,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.danger, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.danger,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
