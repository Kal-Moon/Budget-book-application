import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import 'confirm_sheet.dart';

/// 파일을 사용자가 고른 폴더에 저장한다. 저장했으면 true, 취소했으면 false.
/// 테스트에서는 바꿔 끼운다.
typedef FileSaver = Future<bool> Function(String name, Uint8List bytes);

/// 파일을 다른 앱(카카오톡·드라이브·메일 등)으로 보낸다. 보낼 앱을 골랐으면 true.
typedef FileSharer = Future<bool> Function(String name, Uint8List bytes);

String _mimeOf(String name) => name.endsWith('.xlsx')
    ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    : name.endsWith('.json')
    ? 'application/json'
    : 'application/octet-stream';

final fileSaverProvider = Provider<FileSaver>(
  (ref) => (name, bytes) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: '파일 저장',
      fileName: name,
      bytes: bytes,
      mimeType: _mimeOf(name),
    );
    return uri != null;
  },
);

final fileSharerProvider = Provider<FileSharer>(
  (ref) => (name, bytes) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: name, mimeType: _mimeOf(name))],
        fileNameOverrides: [name],
      ),
    );
    return result.status == ShareResultStatus.success;
  },
);

enum FileDestination { save, share }

/// 파일을 어떻게 내보낼지 묻는다: [폴더에 저장] [다른 앱으로 보내기]. 닫으면 null.
Future<FileDestination?> showFileDestinationSheet(
  BuildContext context, {
  required String title,
}) {
  final c = context.colors;
  Widget option(
    FileDestination value,
    IconData icon,
    String label,
    String description,
  ) => ListTile(
    leading: Icon(icon, color: c.accent),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(
      description,
      style: TextStyle(fontSize: 12, color: c.textMuted),
    ),
    onTap: () => Navigator.of(context).pop(value),
  );
  return showModalBottomSheet<FileDestination>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            option(
              FileDestination.save,
              Icons.folder_outlined,
              '폴더에 저장',
              '다운로드 폴더나 구글 드라이브 같은 곳을 골라 저장해요',
            ),
            option(
              FileDestination.share,
              Icons.share_outlined,
              '다른 앱으로 보내기',
              '카카오톡·메일·드라이브 같은 앱으로 바로 보내요',
            ),
          ],
        ),
      ),
    ),
  );
}

/// 파일을 저장하거나 보낸다(먼저 어느 쪽인지 묻는다). 저장했거나 보낼 앱을 골랐으면 true.
/// [what]은 안내 문구에 쓰는 이름("백업 파일", "엑셀 파일").
Future<bool> deliverFile(
  BuildContext context,
  WidgetRef ref, {
  required String what,
  required String name,
  required Future<Uint8List> Function() build,
}) async {
  final destination = await showFileDestinationSheet(
    context,
    title: '$what을 어떻게 할까요?',
  );
  if (destination == null || !context.mounted) return false;
  try {
    final bytes = await build();
    final done = switch (destination) {
      FileDestination.save => await ref.read(fileSaverProvider)(name, bytes),
      FileDestination.share => await ref.read(fileSharerProvider)(name, bytes),
    };
    if (done && context.mounted) {
      showToast(
        context,
        destination == FileDestination.save
            ? '✓ $what을 저장했어요'
            : '✓ $what을 보냈어요',
      );
    }
    return done;
  } catch (_) {
    if (context.mounted) showToast(context, '$what을 만들지 못했어요. 다시 시도해주세요');
    return false;
  }
}
