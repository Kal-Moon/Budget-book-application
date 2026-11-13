import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/receipt_scanner.dart';
import '../../domain/budget.dart';
import '../../domain/receipt.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import 'receipt_confirm_screen.dart';

/// 영수증으로 입력: 사진 고르기 → 글자 읽기 → 기억해 둔 이름·카테고리 채우기 → 확인 화면.
/// 저장했으면 true.
Future<bool> startReceiptInput(BuildContext context, WidgetRef ref) async {
  final source = await _pickSource(context);
  if (source == null || !context.mounted) return false;

  final navigator = Navigator.of(context);
  List<OcrLine>? lines;
  _showReading(context);
  try {
    lines = await ref.read(receiptScannerProvider)(source);
  } catch (_) {
    navigator.pop();
    if (context.mounted) showToast(context, '영수증을 읽지 못했어요. 다시 시도해주세요');
    return false;
  }
  navigator.pop();
  if (lines == null || !context.mounted) return false;
  final rows = rowsFromLines(lines);
  if (rows.isEmpty) {
    showToast(context, '글자를 찾지 못했어요. 밝은 곳에서 영수증이 꽉 차게 찍어주세요');
    return false;
  }

  final scan = parseReceipt(rows, today: ref.read(todayProvider));
  final db = ref.read(databaseProvider);
  final memories = await db.getReceiptMemories();
  final expenseIds = {
    for (final c in await db.watchCategories(EntryKind.expense).first) c.id,
  };
  final entries = await db.select(db.entries).get();
  if (!context.mounted) return false;

  final initial = applyReceiptMemory(
    scan,
    memories: memories,
    pastEntries: entries,
    expenseCategoryIds: expenseIds,
  );
  final saved = await navigator.push<bool>(
    MaterialPageRoute(builder: (_) => ReceiptConfirmScreen(initial: initial)),
  );
  return saved ?? false;
}

/// 확인 화면에 처음 채울 값.
class ReceiptDraft {
  const ReceiptDraft({
    required this.scan,
    required this.items,
    required this.categoryOf,
    this.placeCategoryId,
  });

  final ReceiptScan scan;

  /// 기억해 둔 이름으로 바꾼 품목들.
  final List<ReceiptItem> items;

  /// 품목별 카테고리(모르면 null).
  final List<int?> categoryOf;

  /// 구매처로 짐작한 카테고리(품목이 없을 때 쓴다).
  final int? placeCategoryId;
}

/// 기억해 둔 이름·카테고리를 채운다.
/// 품목 카테고리: 품목 기억 → 구매처 기억 → 같은 구매처의 최근 내역 카테고리 순.
/// 지금 없는 카테고리(삭제됨)나 수입 카테고리는 쓰지 않는다.
ReceiptDraft applyReceiptMemory(
  ReceiptScan scan, {
  required List<ReceiptMemory> memories,
  required List<Entry> pastEntries,
  required Set<int> expenseCategoryIds,
}) {
  int? valid(int? id) => expenseCategoryIds.contains(id) ? id : null;
  final itemMemory = {
    for (final m in memories)
      if (m.kind == ReceiptMemoryKind.item) m.key: m,
  };
  int? placeCategory;
  final place = scan.place;
  if (place != null && place.isNotEmpty) {
    final key = placeKeyOf(place);
    placeCategory = valid(
      memories
          .where((m) => m.kind == ReceiptMemoryKind.place && m.key == key)
          .firstOrNull
          ?.categoryId,
    );
    if (placeCategory == null) {
      final same =
          pastEntries
              .where(
                (e) =>
                    e.kind == EntryKind.expense &&
                    e.place.isNotEmpty &&
                    placeKeyOf(e.place) == key,
              )
              .toList()
            ..sort(
              (a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'),
            );
      placeCategory = valid(same.firstOrNull?.categoryId);
    }
  }
  final items = <ReceiptItem>[];
  final categoryOf = <int?>[];
  for (final item in scan.items) {
    final m = itemMemory[item.key];
    items.add(
      m != null && m.name.isNotEmpty ? item.copyWith(name: m.name) : item,
    );
    categoryOf.add(valid(m?.categoryId) ?? placeCategory);
  }
  return ReceiptDraft(
    scan: scan,
    items: items,
    categoryOf: categoryOf,
    placeCategoryId: placeCategory,
  );
}

Future<ReceiptSource?> _pickSource(BuildContext context) {
  final c = context.colors;
  Widget row(IconData icon, String label, ReceiptSource source) => ListTile(
    leading: Icon(icon, color: c.textSecondary),
    title: Text(label),
    onTap: () => Navigator.pop(context, source),
  );
  return showModalBottomSheet<ReceiptSource>(
    context: context,
    showDragHandle: true,
    backgroundColor: c.surface0,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              '영수증으로 입력',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          row(Icons.photo_camera_outlined, '사진 찍기', ReceiptSource.camera),
          row(Icons.photo_library_outlined, '앨범에서 고르기', ReceiptSource.gallery),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              '사진은 폰 안에서만 읽고, 저장하거나 밖으로 보내지 않아요.',
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showReading(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => const PopScope(
    canPop: false,
    child: AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Text('영수증을 읽는 중…'),
        ],
      ),
    ),
  ),
);
