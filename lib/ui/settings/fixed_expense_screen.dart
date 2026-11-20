import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../entry/category_picker_sheet.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/confirm_sheet.dart';

final fixedExpensesProvider = StreamProvider<List<FixedExpense>>(
  (ref) => ref.watch(databaseProvider).watchFixedExpenses(),
);

Future<void> openFixedExpenses(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const FixedExpenseScreen()));

String _dayLabel(int day) => day == 31 ? '말일' : '$day일';

String _shortDate(String date) {
  final d = DateTime.parse(date);
  return '${d.month}월 ${d.day}일';
}

/// 설정 > 고정 지출: 매달 정한 날에 자동으로 넣을 지출 목록.
class FixedExpenseScreen extends ConsumerWidget {
  const FixedExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final items = ref.watch(fixedExpensesProvider).value ?? const [];
    final cats = ref.watch(categoryMapProvider).value ?? const {};
    final today = dateKeyOf(ref.watch(todayProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('고정 지출')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '아직 고정 지출이 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
            ),
          for (final f in items)
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
                  onTap: () => _openEditor(context, f),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 8, 4, 8),
                    child: Row(
                      children: [
                        Text(
                          cats[f.categoryId]?.icon ?? '📌',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: f.active ? null : c.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '매달 ${_dayLabel(f.day)} · ${formatWon(f.amount)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                              Text(
                                f.active
                                    ? '다음 입력: ${_shortDate(f.nextDate)}'
                                    : '멈춤',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: c.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          key: ValueKey('fixed-active-${f.id}'),
                          value: f.active,
                          onChanged: (v) => ref
                              .read(databaseProvider)
                              .setFixedExpenseActive(f.id, v, today: today),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _openEditor(context, null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('고정 지출 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: c.borderStrong),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '월세·통신비·구독료처럼 매달 나가는 돈을 등록하면, 그날이 지난 뒤 앱을 열 때 지출 내역으로 '
            '자동으로 입력해요. 입력된 내역은 다른 내역처럼 고치거나 지울 수 있어요.\n'
            '그 달에 없는 날(31일 등)은 그 달 말일에 입력해요. 앱을 오래 열지 않았으면 빠진 달도 함께 입력해요.\n'
            '스위치를 끄면 입력을 멈추고, 다시 켜면 그다음 날짜부터 입력해요(지난 달은 채우지 않아요).',
            style: TextStyle(fontSize: 11.5, height: 1.7, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, FixedExpense? item) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FixedExpenseEditScreen(item: item),
        ),
      );
}

/// 고정 지출 추가·수정.
class FixedExpenseEditScreen extends ConsumerStatefulWidget {
  const FixedExpenseEditScreen({super.key, this.item});

  final FixedExpense? item;

  @override
  ConsumerState<FixedExpenseEditScreen> createState() =>
      _FixedExpenseEditScreenState();
}

class _FixedExpenseEditScreenState
    extends ConsumerState<FixedExpenseEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _place;
  late final TextEditingController _memo;
  int? _categoryId;
  late int _day;

  @override
  void initState() {
    super.initState();
    final f = widget.item;
    _name = TextEditingController(text: f?.name ?? '');
    _amount = TextEditingController(
      text: f == null ? '' : formatNumber(f.amount),
    );
    _place = TextEditingController(text: f?.place ?? '');
    _memo = TextEditingController(text: f?.memo ?? '');
    _categoryId = f?.categoryId;
    _day = f?.day ?? ref.read(todayProvider).day;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _place.dispose();
    _memo.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      parseAmount(_amount.text) > 0 &&
      _categoryId != null;

  Future<void> _save() async {
    final today = dateKeyOf(ref.read(todayProvider));
    final db = ref.read(databaseProvider);
    await db.saveFixedExpense(
      id: widget.item?.id,
      name: _name.text,
      categoryId: _categoryId!,
      amount: parseAmount(_amount.text),
      day: _day,
      place: _place.text,
      memo: _memo.text,
      active: widget.item?.active ?? true,
      today: today,
    );
    // 오늘이 그날이면 바로 입력한다.
    final count = await db.applyFixedExpenses(today);
    if (!mounted) return;
    showToast(context, count > 0 ? '✓ 저장하고 오늘 내역으로 입력했어요' : '✓ 고정 지출을 저장했어요');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showConfirmSheet(
      context,
      title: '고정 지출을 삭제할까요?',
      description: const Text('앞으로 자동으로 입력하지 않아요. 이미 입력된 내역은 그대로 남아요.'),
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteFixedExpense(widget.item!.id);
    if (!mounted) return;
    showToast(context, '고정 지출을 삭제했어요');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final category = ref.watch(categoryMapProvider).value?[_categoryId];

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.textMuted,
        ),
      ),
    );
    InputDecoration box(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: c.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border, width: 0.5),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? '고정 지출 추가' : '고정 지출 수정'),
        actions: [
          if (widget.item != null)
            IconButton(
              tooltip: '삭제',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          label('이름 (내역)'),
          TextField(
            key: const ValueKey('fixed-name'),
            controller: _name,
            maxLength: 30,
            decoration: box('예: 월세, 통신비').copyWith(counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          label('금액'),
          AmountField(
            key: const ValueKey('fixed-amount'),
            controller: _amount,
            textAlign: TextAlign.left,
            onChanged: (_) => setState(() {}),
            decoration: box('0'),
          ),
          label('카테고리'),
          OutlinedButton(
            key: const ValueKey('fixed-category'),
            onPressed: () async {
              final id = await showCategoryPicker(
                context,
                kind: EntryKind.expense,
                selectedId: _categoryId,
              );
              if (id != null) setState(() => _categoryId = id);
            },
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              side: BorderSide(color: c.border),
              foregroundColor: c.textPrimary,
            ),
            child: Text(
              category == null
                  ? '카테고리 선택'
                  : '${category.icon} ${category.name}',
            ),
          ),
          label('매달 며칠'),
          DropdownButtonFormField<int>(
            key: const ValueKey('fixed-day'),
            initialValue: _day,
            decoration: box(''),
            items: [
              for (var d = 1; d <= 31; d++)
                DropdownMenuItem(
                  value: d,
                  child: Text(d == 31 ? '31일 (없는 달은 말일)' : '$d일'),
                ),
            ],
            onChanged: (v) => setState(() => _day = v ?? _day),
          ),
          label('구매처 (선택)'),
          TextField(controller: _place, decoration: box('예: 집주인')),
          label('메모 (선택)'),
          TextField(controller: _memo, decoration: box('')),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
