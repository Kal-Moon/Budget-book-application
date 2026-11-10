import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/categories.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';

/// 카테고리 하나를 고치는 시트: 이름·아이콘·색상·이번 달 예산(항목별 방식의 지출만)·삭제.
/// [siblings]는 같은 종류의 카테고리 전체(이름 중복 검사, 마지막 1개 삭제 막기).
Future<void> showCategoryEditSheet(
  BuildContext context, {
  required Category category,
  required List<Category> siblings,
  required VoidCallback onDelete,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: context.colors.surface0,
  builder: (_) => _CategoryEditSheet(
    category: category,
    siblings: siblings,
    onDelete: onDelete,
  ),
);

class _CategoryEditSheet extends ConsumerStatefulWidget {
  const _CategoryEditSheet({
    required this.category,
    required this.siblings,
    required this.onDelete,
  });

  final Category category;
  final List<Category> siblings;
  final VoidCallback onDelete;

  @override
  ConsumerState<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<_CategoryEditSheet> {
  late final _name = TextEditingController(text: widget.category.name);
  final _budget = TextEditingController();
  late String _icon = widget.category.icon;
  late int _color = widget.category.color;
  bool _budgetLoaded = false;

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  String? get _nameError => validateCategoryName(
    _name.text,
    widget.siblings.where((c) => c.id != widget.category.id).map((c) => c.name),
  );

  Future<void> _save({required bool withBudget}) async {
    if (_nameError != null) return;
    final db = ref.read(databaseProvider);
    final navigator = Navigator.of(context);
    await db.updateCategory(
      widget.category.id,
      name: _name.text,
      icon: _icon,
      color: _color,
    );
    if (withBudget) {
      await db.setCategoryBudget(
        ref.read(currentMonthKeyProvider),
        widget.category.id,
        parseAmount(_budget.text),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final monthKey = ref.watch(currentMonthKeyProvider);
    final budget = ref.watch(monthBudgetProvider(monthKey)).value;
    final showBudget =
        widget.category.kind == EntryKind.expense &&
        budget?.mode == BudgetMode.category;
    if (showBudget && !_budgetLoaded) {
      _budgetLoaded = true;
      final amount = budget!.categoryBudget(widget.category.id);
      if (amount > 0) _budget.text = formatNumber(amount);
    }
    final canDelete = widget.siblings.length > 1;
    final error = _nameError;
    final label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: c.textMuted,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              const Text(
                '카테고리 수정',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(_color).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_icon, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      maxLength: categoryNameMaxLength,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: '이름',
                        counterText: '',
                        errorText: error,
                        isDense: true,
                        filled: true,
                        fillColor: c.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: c.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showBudget) ...[
                const SizedBox(height: 16),
                Text('${monthStartOf(monthKey).month}월 예산', style: label),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AmountField(
                          controller: _budget,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('원', style: TextStyle(color: c.textMuted)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('색상', style: label),
              const SizedBox(height: 9),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (i, color) in categoryColors.indexed)
                    Semantics(
                      label: '색상 ${i + 1}',
                      selected: color == _color,
                      button: true,
                      child: GestureDetector(
                        onTap: () => setState(() => _color = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == _color
                                  ? c.textPrimary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('아이콘', style: label),
              const SizedBox(height: 9),
              GridView.count(
                crossAxisCount: 8,
                shrinkWrap: true,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final icon in categoryIcons)
                    GestureDetector(
                      onTap: () => setState(() => _icon = icon),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: icon == _icon ? c.accentBg : c.surface2,
                          border: Border.all(
                            color: icon == _icon
                                ? c.accent
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: error == null
                    ? () => _save(withBudget: showBudget)
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('저장'),
              ),
              const SizedBox(height: 9),
              OutlinedButton(
                onPressed: canDelete
                    ? () {
                        Navigator.pop(context);
                        widget.onDelete();
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.danger,
                  side: BorderSide(
                    color: canDelete ? c.danger : c.border,
                    width: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('이 카테고리 삭제하기'),
              ),
              if (!canDelete)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '카테고리는 최소 1개 필요해요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
