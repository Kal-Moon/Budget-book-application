import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/categories.dart';
import '../categories/category_manage_screen.dart';
import '../theme.dart';

/// 카테고리 선택 시트. 고른(또는 새로 추가한) 카테고리 id를 돌려준다.
Future<int?> showCategoryPicker(
  BuildContext context, {
  required EntryKind kind,
  int? selectedId,
}) => showModalBottomSheet<int>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: context.colors.surface0,
  builder: (_) => _CategoryPickerSheet(kind: kind, selectedId: selectedId),
);

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  const _CategoryPickerSheet({required this.kind, this.selectedId});

  final EntryKind kind;
  final int? selectedId;

  @override
  ConsumerState<_CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  final _newName = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _quickAdd(List<String> existing) async {
    final name = _newName.text.trim();
    final error = validateCategoryName(name, existing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final id = await ref
        .read(databaseProvider)
        .addCategory(
          kind: widget.kind,
          name: name,
          icon: newCategoryEmojis[existing.length % newCategoryEmojis.length],
          color: newCategoryColor,
        );
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cats = ref.watch(categoriesProvider(widget.kind)).value ?? const [];
    final names = cats.map((c) => c.name).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Text(
                widget.kind == EntryKind.expense ? '지출 카테고리 선택' : '수입 카테고리 선택',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
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
                      onTap: () => Navigator.pop(context, cat.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Color(cat.color).withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                cat.icon,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (cat.id == widget.selectedId)
                              Icon(Icons.check, color: c.accent),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newName,
                      maxLength: categoryNameMaxLength,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _quickAdd(names),
                      decoration: InputDecoration(
                        hintText: '새 카테고리 이름',
                        counterText: '',
                        errorText: _error,
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
                  const SizedBox(width: 7),
                  FilledButton(
                    onPressed: () => _quickAdd(names),
                    child: const Text('추가'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  // 시트를 닫고 관리 화면으로. 돌아오면 다시 골라야 한다.
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  openCategoryManage(navigator.context, kind: widget.kind);
                },
                child: const Text('카테고리 관리 ›'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
