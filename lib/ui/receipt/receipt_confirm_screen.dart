import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/receipt.dart';
import '../entry/category_picker_sheet.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/confirm_sheet.dart';
import 'receipt_flow.dart';

/// 영수증에서 읽은 값을 확인·수정하고 저장하는 화면.
/// 품목마다 카테고리를 고르고, 고른 카테고리 수만큼 내역이 나뉘어 저장된다.
/// 저장하면 true로 닫힌다.
class ReceiptConfirmScreen extends ConsumerStatefulWidget {
  const ReceiptConfirmScreen({super.key, required this.initial});

  final ReceiptDraft initial;

  @override
  ConsumerState<ReceiptConfirmScreen> createState() =>
      _ReceiptConfirmScreenState();
}

class _ReceiptConfirmScreenState extends ConsumerState<ReceiptConfirmScreen> {
  late final _total = TextEditingController(
    text: widget.initial.scan.total == null
        ? ''
        : formatNumber(widget.initial.scan.total!),
  );
  late final _place = TextEditingController(text: widget.initial.place);
  late DateTime _date = widget.initial.scan.date ?? ref.read(todayProvider);
  late String _time =
      widget.initial.scan.time ?? timeKeyOf(ref.read(clockProvider).now());
  late final List<ReceiptItem> _items = [...widget.initial.items];
  late final List<int?> _categoryOf = [...widget.initial.categoryOf];

  /// 품목 후보마다 체크 여부. 후보 합계가 결제 금액과 맞을 때만 처음부터 체크돼 있다.
  late final List<bool> _checked = [
    for (var i = 0; i < widget.initial.items.length; i++)
      i < widget.initial.scan.checked.length && widget.initial.scan.checked[i],
  ];
  late int? _singleCategory = widget.initial.placeCategoryId;
  bool _saving = false;

  @override
  void dispose() {
    _total.dispose();
    _place.dispose();
    super.dispose();
  }

  int get _totalAmount => parseAmount(_total.text);

  List<int> get _selected => [
    for (var i = 0; i < _items.length; i++)
      if (_checked[i]) i,
  ];

  int get _selectedSum => _selected.fold(0, (s, i) => s + _items[i].amount);

  /// 체크한 품목에 모두 카테고리가 있을 때만 저장할 내역을 만든다.
  /// 체크한 품목이 없으면 결제 금액 1건(카테고리 하나).
  ReceiptPlan? _plan() {
    if (_totalAmount <= 0) return null;
    final selected = _selected;
    if (selected.isEmpty) {
      return _singleCategory == null
          ? null
          : planReceiptEntries(
              items: const [],
              categoryOf: const [],
              total: _totalAmount,
              fallbackCategoryId: _singleCategory,
              unpricedNames: widget.initial.scan.unpricedNames,
            );
    }
    if (selected.any((i) => _categoryOf[i] == null)) return null;
    return planReceiptEntries(
      items: [for (final i in selected) _items[i]],
      categoryOf: [for (final i in selected) _categoryOf[i]!],
      total: _totalAmount,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final [h, m] = _time.split(':').map(int.parse).toList();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
    );
    if (picked != null) {
      setState(
        () => _time =
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  /// 구매처 후보를 고르면, 같은 구매처의 최근 내역 카테고리를 아직 안 정한 곳에 채운다.
  void _choosePlace(String place) {
    final key = placeKeyOf(place);
    final past =
        (ref.read(allEntriesProvider).value ?? const <Entry>[])
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
    final guess = past.firstOrNull?.categoryId;
    final expense = ref.read(categoriesProvider(EntryKind.expense)).value;
    final valid = expense != null && expense.any((c) => c.id == guess);
    setState(() {
      _place.text = place;
      if (!valid) return;
      _singleCategory ??= guess;
      for (var i = 0; i < _categoryOf.length; i++) {
        _categoryOf[i] ??= guess;
      }
    });
  }

  Future<int?> _pickCategory(int? current) =>
      showCategoryPicker(context, kind: EntryKind.expense, selectedId: current);

  Future<void> _editItem(int index) async {
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (_) => _ItemEditDialog(item: _items[index]),
    );
    if (result == null) return;
    setState(
      () => _items[index] = _items[index].copyWith(
        name: result.$1,
        amount: result.$2,
      ),
    );
  }

  void _removeItem(int index) => setState(() {
    _items.removeAt(index);
    _categoryOf.removeAt(index);
    _checked.removeAt(index);
  });

  Future<void> _save(ReceiptPlan plan) async {
    if (plan.entries.any((e) => e.amount <= 0)) {
      showToast(context, '0원 이하인 내역이 있어요. 금액을 확인해주세요');
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final place = _place.text.trim();
    final largest = plan.entries
        .reduce((a, b) => b.amount > a.amount ? b : a)
        .categoryId;
    await db.saveReceiptEntries(
      [
        for (final e in plan.entries)
          EntriesCompanion.insert(
            kind: EntryKind.expense,
            date: dateKeyOf(_date),
            time: _time,
            categoryId: e.categoryId,
            amount: e.amount,
            place: Value(place),
            description: Value(e.description),
            memo: Value(e.memo),
          ),
      ],
      [
        for (final (i, item) in _items.indexed)
          if (item.key.isNotEmpty && _checked[i])
            ReceiptMemoriesCompanion.insert(
              kind: ReceiptMemoryKind.item,
              key: item.key,
              name: Value(item.name),
              categoryId: Value(_categoryOf[i]),
            ),
        if (placeKeyOf(place).isNotEmpty)
          ReceiptMemoriesCompanion.insert(
            kind: ReceiptMemoryKind.place,
            key: placeKeyOf(place),
            categoryId: Value(largest),
          ),
        // 사업자번호 → 가게 이름: 다음에 같은 가게 영수증이면 구매처를 자동으로 채운다.
        if (widget.initial.scan.bizNo != null && place.isNotEmpty)
          ReceiptMemoriesCompanion.insert(
            kind: ReceiptMemoryKind.place,
            key: bizKeyOf(widget.initial.scan.bizNo!),
            name: Value(place),
            categoryId: Value(largest),
          ),
      ],
    );
    if (!mounted) return;
    showToast(
      context,
      plan.entries.length == 1
          ? '영수증 내역을 저장했어요'
          : '영수증을 ${plan.entries.length}건으로 나눠 저장했어요',
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final categories = ref.watch(categoryMapProvider).value ?? const {};
    final expenseCats =
        ref.watch(categoriesProvider(EntryKind.expense)).value ?? const [];
    // 구매처 후보를 고를 때 지난 내역에서 카테고리를 짐작하려면 미리 읽어 둬야 한다.
    ref.watch(allEntriesProvider);
    final plan = _plan();

    return Scaffold(
      appBar: AppBar(title: const Text('영수증 확인')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          Text(
            '영수증에서 읽은 값이에요. 틀린 곳은 눌러서 고쳐주세요.',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          const _Label('결제 금액'),
          _Box(
            child: AmountField(
              controller: _total,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: '원',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Label('날짜 & 시간'),
          Row(
            children: [
              Expanded(
                child: _TapBox(
                  icon: Icons.calendar_today_outlined,
                  text:
                      '${_date.year}.${_date.month.toString().padLeft(2, '0')}.'
                      '${_date.day.toString().padLeft(2, '0')}',
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _TapBox(
                  icon: Icons.schedule,
                  text: _time,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _Label('구매처'),
          _Box(
            child: TextField(
              controller: _place,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '아래 후보를 누르거나 직접 입력 (선택)',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          // 한글 상호는 인식이 자주 틀려서 자동으로 채우지 않고 후보로 보여준다.
          if (widget.initial.scan.placeCandidates.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cand in widget.initial.scan.placeCandidates)
                  ActionChip(
                    label: Text(cand),
                    onPressed: () => _choosePlace(cand),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (_selected.isEmpty) ...[
            const _Label('카테고리'),
            Text(
              _items.isNotEmpty
                  ? '체크한 품목이 없어서 결제 금액 그대로 한 건으로 저장해요.'
                  : widget.initial.scan.unpricedNames.isEmpty
                  ? '품목을 찾지 못했어요. 결제 금액 그대로 한 건으로 저장해요.'
                  : '품목별 가격이 없어서 결제 금액 그대로 한 건으로 저장해요. '
                        '(${widget.initial.scan.unpricedNames.join(', ')})',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
            const SizedBox(height: 8),
            _CategoryChip(
              category: categories[_singleCategory],
              onTap: () async {
                final id = await _pickCategory(_singleCategory);
                if (id != null) setState(() => _singleCategory = id);
              },
            ),
            const SizedBox(height: 20),
          ],
          if (_items.isNotEmpty) ...[
            _Label('품목 후보 ${_items.length}개'),
            Text(
              '나눠 저장할 품목을 체크하세요. 체크하지 않으면 결제 금액 1건으로 저장해요.',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
            const SizedBox(height: 8),
            for (final (i, item) in _items.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(2, 6, 4, 6),
                decoration: BoxDecoration(
                  color: c.surface2,
                  border: Border.all(color: c.border, width: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _checked[i],
                      onChanged: (v) =>
                          setState(() => _checked[i] = v ?? false),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _editItem(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                formatWon(item.amount),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_checked[i])
                      _CategoryChip(
                        category: categories[_categoryOf[i]],
                        onTap: () async {
                          final id = await _pickCategory(_categoryOf[i]);
                          if (id != null) setState(() => _categoryOf[i] = id);
                        },
                      ),
                    IconButton(
                      tooltip: '이 품목 빼기',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 18, color: c.textMuted),
                      onPressed: () => _removeItem(i),
                    ),
                  ],
                ),
              ),
            // 선택 합계와 결제 금액이 맞는지(맞지 않으면 할인 등으로 보고 가장 큰 쪽에서 조정한다).
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  _selectedSum == _totalAmount
                      ? '선택 합계 ${formatWon(_selectedSum)} = 결제 ${formatWon(_totalAmount)} ✓'
                      : '선택 합계 ${formatWon(_selectedSum)} / 결제 ${formatWon(_totalAmount)} '
                            '(차이 ${formatWon((_selectedSum - _totalAmount).abs())})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _selectedSum == _totalAmount
                        ? c.income
                        : c.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '한 번에 정하기 (체크한 품목)',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in expenseCats)
                  ActionChip(
                    label: Text('전부 ${cat.icon} ${cat.name}'),
                    onPressed: () => setState(() {
                      for (final i in _selected) {
                        _categoryOf[i] = cat.id;
                      }
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _Label(plan == null ? '저장될 내역' : '저장될 내역 (${plan.entries.length}건)'),
          if (plan == null)
            Text(
              _totalAmount <= 0
                  ? '결제 금액을 입력해주세요'
                  : _selected.isEmpty
                  ? '카테고리를 골라주세요'
                  : '체크한 품목의 카테고리를 모두 골라주세요',
              style: TextStyle(fontSize: 12.5, color: c.danger),
            )
          else ...[
            for (final e in plan.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      categories[e.categoryId]?.icon ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          categories[e.categoryId]?.name ?? '',
                          if (e.description.isNotEmpty) e.description,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      formatWon(e.amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (plan.adjustedCategoryId != null)
              Text(
                plan.adjustment > 0
                    ? "할인 등 ${formatWon(plan.adjustment)}은 "
                          "'${categories[plan.adjustedCategoryId]?.name}'에서 뺐어요"
                    : "품목 합계가 결제 금액보다 ${formatWon(-plan.adjustment)} 적어서 "
                          "'${categories[plan.adjustedCategoryId]?.name}'에 더했어요",
                style: TextStyle(fontSize: 11.5, color: c.textMuted),
              ),
            Text(
              '품목 목록은 메모에 함께 저장돼요.',
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '인식된 글자 보기',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    widget.initial.scan.rows.join('\n'),
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('글자 복사'),
                    onPressed: () async {
                      // 줄 단위 글자 + 진단용 조각 위치(잘못 읽은 영수증을 테스트로 재현할 때 쓴다).
                      final scan = widget.initial.scan;
                      await Clipboard.setData(
                        ClipboardData(
                          text: [
                            ...scan.rows,
                            if (scan.fragments.isNotEmpty) ...[
                              '',
                              '--- 진단용 조각 위치 ---',
                              ...scan.fragments,
                            ],
                          ].join('\n'),
                        ),
                      );
                      if (context.mounted) showToast(context, '복사했어요');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: c.surface0,
            border: Border(top: BorderSide(color: c.border, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: plan == null || _saving ? null : () => _save(plan),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    plan == null || plan.entries.length <= 1
                        ? '저장'
                        : '저장 (${plan.entries.length}건)',
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('취소'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: context.colors.textSecondary,
      ),
    ),
  );
}

class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: context.colors.surface2,
      border: Border.all(color: context.colors.border, width: 0.5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

class _TapBox extends StatelessWidget {
  const _TapBox({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: _Box(
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.textMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 품목 옆 카테고리 칩. 아직 안 골랐으면 "카테고리" (빨간 글씨).
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cat = category;
    return Material(
      color: cat == null
          ? c.dangerBg
          : Color(cat.color).withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            cat == null ? '카테고리 ▾' : '${cat.icon} ${cat.name} ▾',
            style: TextStyle(
              fontSize: 12.5,
              color: cat == null ? c.danger : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 품목 이름·금액 고치기. 고친 (이름, 금액)을 돌려준다.
class _ItemEditDialog extends StatefulWidget {
  const _ItemEditDialog({required this.item});

  final ReceiptItem item;

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _amount = TextEditingController(
    text: formatNumber(widget.item.amount),
  );

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty && parseAmount(_amount.text) > 0;
    return AlertDialog(
      title: const Text('품목 고치기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '이름'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          AmountField(
            controller: _amount,
            textAlign: TextAlign.left,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: '금액', suffixText: '원'),
          ),
          const SizedBox(height: 10),
          Text(
            '고친 이름은 기억해 두었다가 다음 영수증에서 그대로 보여줘요.',
            style: TextStyle(fontSize: 11.5, color: context.colors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: valid
              ? () => Navigator.pop(context, (
                  _name.text.trim(),
                  parseAmount(_amount.text),
                ))
              : null,
          child: const Text('확인'),
        ),
      ],
    );
  }
}
