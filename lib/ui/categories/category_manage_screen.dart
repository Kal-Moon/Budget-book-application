import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/categories.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import 'category_edit_sheet.dart';

/// 카테고리 관리 화면을 연다. [kind]는 처음 보여줄 탭.
Future<void> openCategoryManage(
  BuildContext context, {
  EntryKind kind = EntryKind.expense,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => CategoryManageScreen(initialKind: kind),
  ),
);

/// 카테고리 관리: [지출][수입] 탭, 추가·이름·아이콘·색상·예산(지출만)·삭제.
class CategoryManageScreen extends ConsumerStatefulWidget {
  const CategoryManageScreen({super.key, this.initialKind = EntryKind.expense});

  final EntryKind initialKind;

  @override
  ConsumerState<CategoryManageScreen> createState() =>
      _CategoryManageScreenState();
}

class _CategoryManageScreenState extends ConsumerState<CategoryManageScreen> {
  late EntryKind _kind = widget.initialKind;

  Future<void> _add(List<Category> cats) async {
    final db = ref.read(databaseProvider);
    final id = await db.addCategory(
      kind: _kind,
      name: uniqueNewCategoryName(cats.map((c) => c.name)),
      icon: newCategoryEmojis[cats.length % newCategoryEmojis.length],
      color: newCategoryColor,
    );
    final added = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingle();
    if (mounted) await _edit(added, [...cats, added]);
  }

  Future<void> _edit(Category cat, List<Category> cats) =>
      showCategoryEditSheet(
        context,
        category: cat,
        siblings: cats,
        onDelete: () => _delete(cat, cats),
      );

  /// 삭제 흐름. 내역이 있으면 옮길지 함께 지울지 고르고, 어느 쪽이든 한 번 더 확인한다.
  Future<void> _delete(Category cat, List<Category> cats) async {
    if (cats.length <= 1) {
      showToast(context, '카테고리는 최소 1개 필요해요');
      return;
    }
    final db = ref.read(databaseProvider);
    final count = await db.countEntriesIn(cat.id);
    if (!mounted) return;

    int? moveTo;
    if (count > 0) {
      final choice = await _showMoveSheet(cat, cats, count);
      if (choice == null || !mounted) return;
      moveTo = choice == _deleteWithEntries ? null : choice;
    }

    final target = cats.where((c) => c.id == moveTo).firstOrNull;
    final ok = await showConfirmSheet(
      context,
      title: target != null
          ? "'${target.name}'(으)로 옮길까요?"
          : count > 0
          ? '내역도 함께 삭제할까요?'
          : '카테고리를 삭제할까요?',
      description: Text(
        target != null
            ? "'${cat.name}'의 내역 $count건과 예산을 '${target.name}'(으)로 옮기고, "
                  "'${cat.name}' 카테고리를 삭제해요."
            : count > 0
            ? "'${cat.name}' 카테고리의 내역 $count건이 전부 사라져요. 이 작업은 되돌릴 수 없어요."
            : "'${cat.name}' 카테고리를 삭제해요.",
      ),
      confirmLabel: target != null
          ? '옮기고 삭제'
          : count > 0
          ? '내역까지 삭제'
          : '삭제하기',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await db.deleteCategory(cat.id, moveTo: moveTo);
    if (mounted) {
      showToast(context, target != null ? '삭제하고 내역을 옮겼어요' : '삭제됐어요');
    }
  }

  static const _deleteWithEntries = -1;

  /// 옮길 카테고리 id, 함께 삭제면 [_deleteWithEntries], 닫으면 null.
  Future<int?> _showMoveSheet(Category cat, List<Category> cats, int count) {
    final c = context.colors;
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: c.surface0,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Text(
                "'${cat.name}' 삭제",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '이 카테고리로 기록된 $count건의 내역을 다른 카테고리로 옮길 수 있어요. '
                '옮길 카테고리를 골라주세요. 예산도 함께 옮겨져요.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              for (final other in cats.where((o) => o.id != cat.id))
                _SheetRow(
                  icon: other.icon,
                  iconBackground: Color(other.color).withValues(alpha: 0.13),
                  label: '${other.name}(으)로 옮기기',
                  onTap: () => Navigator.pop(context, other.id),
                ),
              _SheetRow(
                icon: '🗑️',
                iconBackground: c.dangerBg,
                label: '옮기지 않고 내역까지 함께 삭제',
                color: c.danger,
                onTap: () => Navigator.pop(context, _deleteWithEntries),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cats = ref.watch(categoriesProvider(_kind)).value ?? const [];
    final monthKey = ref.watch(currentMonthKeyProvider);
    final budget = ref.watch(monthBudgetProvider(monthKey)).value;
    final showBudget =
        _kind == EntryKind.expense && budget?.mode == BudgetMode.category;

    return Scaffold(
      appBar: AppBar(title: const Text('카테고리 관리')),
      body: Column(
        children: [
          Container(
            color: c.surface2,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                for (final (i, kind) in EntryKind.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: _TabChip(
                      label: kind == EntryKind.expense ? '지출' : '수입',
                      selected: kind == _kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                for (final cat in cats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: c.surface2,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: c.border, width: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _edit(cat, cats),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Color(cat.color)
                                      .withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  cat.icon,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: Color(cat.color),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (showBudget)
                                Text(
                                  formatWon(budget!.categoryBudget(cat.id)),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                              Icon(Icons.chevron_right, color: c.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _add(cats),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('카테고리 추가'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: c.borderStrong),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '카테고리를 누르면 이름·아이콘·색상을 바꾸거나 삭제할 수 있어요.\n'
                  '색상은 아이콘 배경, 목록 앞 작은 점, 차트에 적용돼요. (글자 색은 바뀌지 않아요)'
                  '${_kind == EntryKind.expense && !showBudget ? '\n카테고리별 예산은 예산 방식이 "항목별로 정하기"일 때 정할 수 있어요.' : ''}',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.7,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accentBg : c.surface0,
          border: Border.all(color: selected ? c.accent : c.border, width: 1.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? c.accent : c.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.iconBackground,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String icon;
  final Color iconBackground;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.surface2,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color ?? c.border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
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
