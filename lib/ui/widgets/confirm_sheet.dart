import 'package:flutter/material.dart';

import '../theme.dart';

/// 확인 시트(이전 앱의 openGenericConfirm). 확인을 누르면 true.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required Widget description,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool destructive = false,
}) async {
  final c = context.colors;
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: c.surface0,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: c.textSecondary,
              ),
              child: description,
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? c.danger : c.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: 9),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// 화면 아래쪽에 잠깐 뜨는 안내(이전 앱의 토스트).
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
      ),
    );
}
