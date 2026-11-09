import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../entry/entry_editor.dart';
import '../navigation.dart';

/// 하단 "입력" 탭. 탭을 열 때마다 빈 입력 화면으로 시작하고, 끝나면 홈으로 간다.
class InputScreen extends ConsumerWidget {
  const InputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => EntryEditor(
    key: ValueKey(ref.watch(inputSessionProvider)),
    handleBack: ref.watch(appTabProvider) == AppTab.input,
    onDone: () => ref.read(appTabProvider.notifier).select(AppTab.home),
  );
}

/// 기존 내역 수정 화면(홈 목록에서 눌렀을 때).
Future<void> openEntryEditor(BuildContext context, Entry entry) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EntryEditor(
          entry: entry,
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    );
