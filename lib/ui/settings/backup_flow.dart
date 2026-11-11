import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../data/backup.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../analysis/analysis_view.dart';
import '../home/home_view.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';

/// 백업 파일을 사용자가 고른 폴더에 저장한다. 저장했으면 true, 취소했으면 false.
/// 테스트에서는 바꿔 끼운다.
typedef BackupFileSaver = Future<bool> Function(String name, Uint8List bytes);

final backupFileSaverProvider = Provider<BackupFileSaver>(
  (ref) => (name, bytes) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: '백업 파일 저장',
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
    );
    return uri != null;
  },
);

/// 복원할 백업 파일을 고른다. 취소하면 null. 테스트에서는 바꿔 끼운다.
final backupFilePickerProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => () async {
    // 파일 관리자마다 .json을 다르게 분류해서 종류를 거르지 않고, 내용으로 확인한다.
    final file = await FilePicker.pickFile(dialogTitle: '백업 파일 선택');
    if (file == null) return null;
    return file.xFile.readAsBytes();
  },
);

/// 백업 파일을 만들어 저장한다. 저장했으면 true.
Future<bool> saveBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void toast(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
      ),
    );

  final now = ref.read(clockProvider).now();
  try {
    final bytes = await createBackup(
      ref.read(databaseProvider),
      settings: ref.read(settingsProvider.notifier).exportValues(),
      now: now,
    );
    final saved = await ref.read(backupFileSaverProvider)(
      backupFileName(now),
      bytes,
    );
    if (saved) toast('✓ 백업 파일을 저장했어요');
    return saved;
  } catch (_) {
    toast('백업 파일을 저장하지 못했어요. 다시 시도해주세요');
    return false;
  }
}

/// 백업에서 복원: 파일 선택 → 내용 확인 → 확인창(항상) → 지금 데이터를 모두 바꾼다.
Future<void> startRestoreFlow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void toast(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
      ),
    );

  final db = ref.read(databaseProvider);
  final Uint8List? bytes;
  try {
    bytes = await ref.read(backupFilePickerProvider)();
  } catch (_) {
    toast('파일을 열 수 없어요');
    return;
  }
  if (bytes == null || !context.mounted) return;

  final BackupFile backup;
  try {
    backup = parseBackup(bytes, schemaVersion: db.schemaVersion);
  } on BackupException catch (e) {
    toast(e.message);
    return;
  }

  final c = context.colors;
  final ok = await showConfirmSheet(
    context,
    title: '백업에서 복원할까요?',
    description: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text:
                '${_formatTime(backup.createdAt)}에 만든 백업이에요 · '
                '내역 ${backup.entryCount}건 · 카테고리 ${backup.categoryCount}개\n',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
          ),
          const TextSpan(
            text:
                '지금 앱에 있는 내역·카테고리·예산과 설정이 모두 백업 내용으로 바뀌어요. '
                '앱 잠금은 그대로예요.\n',
          ),
          TextSpan(
            text: '지금 데이터는 되돌릴 수 없어요.',
            style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
    confirmLabel: '복원하기',
    destructive: true,
  );
  if (!ok || !context.mounted) return;

  final container = ProviderScope.containerOf(context);
  try {
    await restoreRecords(db, backup);
  } on BackupException catch (e) {
    toast(e.message);
    return;
  }
  await container.read(settingsProvider.notifier).replaceWith(backup.settings);
  // 화면 상태(보던 탭·달·필터)도 처음으로.
  container.invalidate(homeViewProvider);
  container.invalidate(analysisViewProvider);
  container.read(appTabProvider.notifier).select(AppTab.home);
  toast('✓ 백업에서 복원했어요');
}

String _formatTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}.${two(t.month)}.${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
