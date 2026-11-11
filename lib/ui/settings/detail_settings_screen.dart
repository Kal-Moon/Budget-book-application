import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';
import '../widgets/confirm_sheet.dart';
import 'settings_widgets.dart';

/// 세부 설정: 실수 방지, 글자 크기, 예산 초과 미리 알림. 기본값은 모두 꺼짐/기본.
class DetailSettingsScreen extends ConsumerWidget {
  const DetailSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
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
        ],
      ),
    );
  }
}
