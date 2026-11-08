import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '예산, 카테고리, 세부 설정, 데이터 가져오기·초기화는\n다음 단계에서 옮겨올 예정이에요',
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
