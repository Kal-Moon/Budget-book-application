import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../categories/category_manage_screen.dart';
import '../theme.dart';

final _versionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final version = ref.watch(_versionProvider).value ?? '—';
    final expenseCount =
        ref.watch(categoriesProvider(EntryKind.expense)).value?.length ?? 0;
    final incomeCount =
        ref.watch(categoriesProvider(EntryKind.income)).value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '카테고리',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 9),
          Material(
            color: c.surface2,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: c.border, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => openCategoryManage(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('카테고리 관리', style: TextStyle(fontSize: 13.5)),
                    ),
                    Text(
                      '지출 $expenseCount개 · 수입 $incomeCount개 ›',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '예산 설정, 세부 설정, 데이터 가져오기·초기화는\n다음 단계에서 옮겨올 예정이에요',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, height: 1.7),
          ),
          const SizedBox(height: 24),
          Text(
            '가계부 · ver.$version · 데이터는 이 기기에 저장돼요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
