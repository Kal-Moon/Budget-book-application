import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/today.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/analysis.dart';
import '../../domain/budget.dart';
import '../lock/lock_controller.dart';
import '../lock/lock_setup.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import 'settings_widgets.dart';

/// 세부 설정: 실수 방지, 글자 크기, 예산 초과 미리 알림, 분석 강조색, 앱 잠금. 기본값은 모두 꺼짐/기본.
class DetailSettingsScreen extends ConsumerWidget {
  const DetailSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final lock = ref.watch(lockProvider);
    final highlight = highlightColorOf(s.highlightColor);
    final categoryMode =
        ref
            .watch(monthBudgetProvider(ref.watch(currentMonthKeyProvider)))
            .value
            ?.mode ==
        BudgetMode.category;
    return Scaffold(
      appBar: AppBar(title: const Text('세부 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          SettingsSection(
            title: '실수 방지',
            children: [
              SettingsToggle(
                label: '저장·취소 전에 한 번 더 확인',
                description: '입력 화면에서 저장이나 취소를 누르면 실행하기 전에 확인창을 한 번 더 보여줘요',
                value: s.mistapProtection,
                onChanged: (v) {
                  notifier.update((s) => s.copyWith(mistapProtection: v));
                  showToast(
                    context,
                    v ? '저장·취소 전에 한 번 더 물어볼게요' : '바로 저장·취소되도록 되돌렸어요',
                  );
                },
              ),
              SettingsToggle(
                label: '뒤로가기로 종료 시 확인',
                description: '홈 화면에서 뒤로가기를 누르면 바로 나가지 않고 종료할지 한 번 물어봐요',
                value: s.exitConfirm,
                onChanged: (v) {
                  notifier.update((s) => s.copyWith(exitConfirm: v));
                  showToast(
                    context,
                    v ? '뒤로가기로 나갈 때 한 번 더 물어볼게요' : '바로 종료되도록 되돌렸어요',
                  );
                },
              ),
            ],
          ),
          SettingsSection(
            title: '글자 크기',
            children: [
              SettingsChoice<FontSizeOption>(
                items: FontSizeOption.values,
                selected: s.fontSize,
                labelOf: (f) => switch (f) {
                  FontSizeOption.small => '작게',
                  FontSizeOption.medium => '보통',
                  FontSizeOption.large => '크게',
                },
                onSelected: (f) =>
                    notifier.update((s) => s.copyWith(fontSize: f)),
              ),
            ],
          ),
          SettingsSection(
            title: '예산 초과 미리 알림',
            children: [
              const SettingsNote('예산을 다 쓰기 전에, 지정한 비율에 도달하면 미리 "초과" 표시로 알려줘요.'),
              SettingsChoice<int>(
                items: const [80, 90, 100],
                selected: s.budgetThreshold,
                labelOf: (v) => v == 100 ? '100% (다 썼을 때)' : '$v%',
                onSelected: (v) {
                  notifier.update((s) => s.copyWith(budgetThreshold: v));
                  showToast(
                    context,
                    v == 100 ? '예산을 다 썼을 때만 초과로 표시해요' : '예산의 $v%에 도달하면 미리 알려줘요',
                  );
                },
              ),
            ],
          ),
          SettingsSection(
            title: '분석 화면 강조 표시',
            children: [
              const SettingsNote('예산을 넘은 카테고리를 분석 화면에서 이 색으로 강조해요.'),
              if (categoryMode)
                SettingsToggle(
                  label: '총 지출도 함께 강조',
                  description: '항목별 예산의 합계를 넘으면 가운데 총 지출 금액도 강조해요',
                  value: s.totalHighlightInCategoryMode,
                  onChanged: (v) => notifier.update(
                    (s) => s.copyWith(totalHighlightInCategoryMode: v),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final h in highlightColors)
                    Semantics(
                      label: '강조색 ${h.key}',
                      selected: h.key == highlight.key,
                      button: true,
                      child: GestureDetector(
                        onTap: () => notifier.update(
                          (s) => s.copyWith(highlightColor: h.key),
                        ),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(h.swatch),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: h.key == highlight.key
                                  ? context.colors.textPrimary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const SettingsNote('이렇게 표시돼요'),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Color(highlight.background),
                  border: Border.all(
                    color: Color(highlight.border),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text('🍚', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 9),
                    const Text('식비', style: TextStyle(fontSize: 13)),
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Color(highlight.text),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '초과',
                        style: TextStyle(fontSize: 9.5, color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '120,000원',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(highlight.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SettingsSection(
            title: '앱 잠금',
            children: [
              SettingsToggle(
                label: 'PIN으로 잠그기',
                description: lock.enabled
                    ? '설정됨 · 앱을 열 때마다 4자리 번호를 입력해요'
                    : '앱을 열 때마다 4자리 번호를 입력해야 해요',
                value: lock.enabled,
                onChanged: (v) async {
                  if (v) {
                    await startLockSetup(context, ref);
                  } else if (await confirmCurrentPin(context)) {
                    await ref.read(lockProvider.notifier).disable();
                    if (context.mounted) showToast(context, '앱 잠금을 껐어요');
                  }
                },
              ),
              if (lock.enabled) ...[
                SettingsRow(
                  label: 'PIN 바꾸기',
                  onTap: () async {
                    if (!await confirmCurrentPin(context) || !context.mounted) {
                      return;
                    }
                    final pin = await askNewPin(context);
                    if (pin == null) return;
                    await ref.read(lockProvider.notifier).setPin(pin);
                    if (context.mounted) showToast(context, '✓ PIN을 바꿨어요');
                  },
                ),
                SettingsRow(
                  label: 'PIN을 잊었을 때',
                  value: switch ((lock.biometric, lock.question != null)) {
                    (true, true) => '지문·얼굴 + 질문',
                    (true, false) => '지문·얼굴',
                    (false, true) => '질문',
                    (false, false) => '정하지 않음',
                  },
                  onTap: () async {
                    if (!await confirmCurrentPin(context) || !context.mounted) {
                      return;
                    }
                    if (await editRecovery(context) && context.mounted) {
                      showToast(context, '✓ 복구 방법을 저장했어요');
                    }
                  },
                ),
              ],
              const SettingsNote(
                '앱을 1분 넘게 떠나 있다가 돌아오면 다시 잠겨요. '
                '다른 사람이 폰을 잠깐 볼 때를 막는 간단한 보호 기능이에요.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
