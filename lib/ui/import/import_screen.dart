import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../data/import_reader.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/import.dart';
import '../navigation.dart';
import '../settings/settings_widgets.dart';
import '../theme.dart';

/// 사용자가 고른 파일. 테스트에서는 [importFilePickerProvider]를 바꿔 끼운다.
typedef PickedImportFile = ({String name, Uint8List bytes});

final importFilePickerProvider = Provider<Future<PickedImportFile?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.xFile.readAsBytes());
  },
);

Future<void> openImport(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ImportScreen()));

const _stepCount = 5;

/// 다른 가계부에서 가져오기: 파일 → 열 확인 → 카테고리 연결 → 미리보기 → 완료.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  int _step = 0;
  String? _fileName;
  ImportTable? _table;
  ImportMapping? _mapping;
  ImportParseResult? _parsed;
  String? _error;
  bool _busy = false;

  /// 종류 → 파일의 분류 이름 → 연결할 카테고리 id(null이면 새로 만들기).
  final Map<EntryKind, Map<String, int?>> _choices = {};
  (int, int)? _imported;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final picked = await ref.read(importFilePickerProvider)();
      if (picked == null || !mounted) return;
      final table = readImportFile(picked.name, picked.bytes);
      setState(() {
        _fileName = picked.name;
        _table = table;
        _mapping = guessMapping(table);
      });
    } on ImportReadException catch (e) {
      setState(() {
        _error = e.message;
        _fileName = null;
        _table = null;
      });
    } catch (_) {
      setState(() => _error = '파일을 읽는 중 오류가 발생했어요.');
    }
  }

  Future<void> _next() async {
    switch (_step) {
      case 0:
        setState(() => _step = 1);
      case 1:
        final m = _mapping!;
        if (m.date < 0 || m.amount < 0) {
          setState(() => _error = '날짜와 금액 열은 반드시 지정해야 해요.');
          return;
        }
        if (m.typeMode == ImportTypeMode.column && m.type < 0) {
          setState(() => _error = '수입/지출을 구분할 열을 지정해주세요.');
          return;
        }
        // 지금 고른 열 연결로 읽은 뒤, 그 결과로 카테고리 목록을 만든다.
        final parsed = parseImportRows(_table!, m);
        final all = await ref.read(databaseProvider).watchAllCategories().first;
        if (!mounted) return;
        _choices.clear();
        for (final kind in EntryKind.values) {
          _choices[kind] = {
            for (final raw in parsed.categoriesOf(kind))
              raw: all
                  .where((c) => c.kind == kind && c.name == raw.trim())
                  .firstOrNull
                  ?.id,
          };
        }
        setState(() {
          _error = null;
          _parsed = parsed;
          _step = 2;
        });
      case 2:
        setState(() => _step = 3);
      case 3:
        setState(() => _busy = true);
        final result = await ref
            .read(databaseProvider)
            .importEntries(_parsed!.rows, _choices);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _imported = result;
          _step = 4;
        });
      case 4:
        ref.read(appTabProvider.notifier).select(AppTab.home);
        Navigator.of(context).pop();
    }
  }

  void _back() {
    if (_step > 0 && _step < 4) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canNext = switch (_step) {
      0 => _table != null,
      3 => !_busy && _parsed!.rows.isNotEmpty,
      _ => true,
    };
    return PopScope(
      canPop: _step == 0 || _step == 4,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('다른 가계부에서 가져오기'),
          leading: _step > 0 && _step < 4
              ? IconButton(
                  tooltip: '이전 단계',
                  onPressed: _back,
                  icon: const Icon(Icons.chevron_left),
                )
              : null,
          automaticallyImplyLeading: false,
          actions: [
            if (_step < 4)
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Row(
                children: [
                  for (var i = 0; i < _stepCount; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _step ? c.accent : c.surface2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                children: switch (_step) {
                  0 => _fileStep(c),
                  1 => _mappingStep(c),
                  2 => _categoryStep(c),
                  3 => _previewStep(c),
                  _ => _doneStep(c),
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: FilledButton(
              onPressed: canNext ? _next : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(switch (_step) {
                0 => _table == null ? '파일을 선택하세요' : '다음',
                3 => '가져오기',
                4 => '완료',
                _ => '다음',
              }),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _title(AppColors c, String title, [String? description]) => [
    Text(
      title,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
    ),
    if (description != null)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          description,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.65,
            color: c.textSecondary,
          ),
        ),
      ),
    const SizedBox(height: 16),
  ];

  Widget _errorBox(AppColors c) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: c.dangerBg,
      border: Border.all(color: c.danger, width: 0.5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      _error!,
      style: const TextStyle(fontSize: 12, color: Color(0xFFA32D2D)),
    ),
  );

  Widget _hint(AppColors c, String text) => Container(
    margin: const EdgeInsets.only(top: 15),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: c.surface2,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, height: 1.65, color: c.textSecondary),
    ),
  );

  // 1단계: 파일 고르기
  List<Widget> _fileStep(AppColors c) => [
    ..._title(
      c,
      '파일을 선택해주세요',
      '쓰던 가계부 앱에서 내보내기 한 엑셀(.xlsx) 또는 CSV 파일을 골라주세요. '
          '대부분의 가계부 앱은 설정 화면에 "데이터 내보내기" 메뉴가 있어요.',
    ),
    OutlinedButton(
      onPressed: _pickFile,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 26),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        children: [
          const Text('📄', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(
            _fileName == null ? '파일 선택' : '다른 파일 선택',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            '엑셀(.xlsx), CSV 지원',
            style: TextStyle(fontSize: 11.5, color: c.textMuted),
          ),
        ],
      ),
    ),
    if (_fileName != null)
      Container(
        margin: const EdgeInsets.only(top: 13),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 19, color: c.accent),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _fileName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            Text(
              '${_table!.rows.length}줄',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
          ],
        ),
      ),
    if (_error != null) _errorBox(c),
    _hint(
      c,
      'Tip. 파일 첫 줄은 "날짜", "금액" 같은 항목 이름(헤더)이어야 해요. '
      '다음 단계에서 어떤 열이 무엇인지 직접 확인하고 바꿀 수 있어요.',
    ),
  ];

  // 2단계: 열 확인
  List<Widget> _mappingStep(AppColors c) {
    final table = _table!;
    final m = _mapping!;
    Widget row(
      String label,
      int value,
      ImportMapping Function(int) change, {
      bool allowNone = true,
    }) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(13, 2, 9, 2),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text('←', style: TextStyle(fontSize: 12, color: c.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<int>(
              key: ValueKey('map-$label'),
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: TextStyle(fontSize: 12.5, color: c.textPrimary),
              items: [
                if (allowNone || value < 0)
                  DropdownMenuItem(
                    value: -1,
                    child: Text(allowNone ? '없음' : '선택해주세요'),
                  ),
                for (final (i, h) in table.headers.indexed)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      '${i + 1}열: $h',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                _mapping = change(v ?? -1);
                _error = null;
              }),
            ),
          ),
        ],
      ),
    );

    return [
      ..._title(c, '항목을 확인해주세요', '파일의 각 열이 어떤 정보인지 확인하고, 다르면 바꿔주세요.'),
      row('날짜', m.date, (v) => m.copyWith(date: v), allowNone: false),
      row('금액', m.amount, (v) => m.copyWith(amount: v), allowNone: false),
      row('카테고리', m.category, (v) => m.copyWith(category: v)),
      row('구매처', m.place, (v) => m.copyWith(place: v)),
      row('내역', m.description, (v) => m.copyWith(description: v)),
      row('메모', m.memo, (v) => m.copyWith(memo: v)),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Text(
          '수입/지출은 어떻게 구분할까요?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
      ),
      SettingsChoice<ImportTypeMode>(
        items: ImportTypeMode.values,
        selected: m.typeMode,
        labelOf: (t) => switch (t) {
          ImportTypeMode.sign => '금액 부호로',
          ImportTypeMode.column => '별도 열로',
          ImportTypeMode.allExpense => '전부 지출로',
        },
        onSelected: (t) => setState(() {
          _mapping = m.copyWith(typeMode: t);
          _error = null;
        }),
      ),
      const SizedBox(height: 10),
      if (m.typeMode == ImportTypeMode.column)
        row('구분 열', m.type, (v) => m.copyWith(type: v), allowNone: false),
      _hint(c, switch (m.typeMode) {
        ImportTypeMode.sign => '금액 부호로: 음수(-)는 지출, 양수는 수입으로 처리해요.',
        ImportTypeMode.column => '별도 열로: 지정한 열의 값(예: "수입"/"지출")을 보고 구분해요.',
        ImportTypeMode.allExpense =>
          '전부 지출로: 파일의 모든 내역을 지출로 가져와요. 수입 기록이 없는 파일에 적합해요.',
      }),
      if (_error != null) _errorBox(c),
    ];
  }

  // 3단계: 카테고리 연결
  List<Widget> _categoryStep(AppColors c) {
    final all = ref.watch(categoryMapProvider).value?.values.toList() ?? [];
    List<Widget> section(EntryKind kind, String title) {
      final choices = _choices[kind] ?? const {};
      if (choices.isEmpty) return const [];
      final cats = all.where((cat) => cat.kind == kind).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
            ),
          ),
        ),
        for (final raw in choices.keys)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border.all(color: c.border, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    raw,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text('→', style: TextStyle(fontSize: 12, color: c.textMuted)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: DropdownButton<int>(
                    key: ValueKey('cat-${kind.name}-$raw'),
                    // -1은 "새 카테고리로 만들기"
                    value: cats.any((cat) => cat.id == choices[raw])
                        ? choices[raw]
                        : -1,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(fontSize: 12.5, color: c.textPrimary),
                    items: [
                      for (final cat in cats)
                        DropdownMenuItem(
                          value: cat.id,
                          child: Text(
                            '${cat.icon} ${cat.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('✨ 새 카테고리로 만들기'),
                      ),
                    ],
                    onChanged: (v) => setState(
                      () => _choices[kind]![raw] = v == -1 ? null : v,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ];
    }

    final parsed = _parsed!;
    final hasBlank = parsed.rows.any((r) => r.categoryRaw.isEmpty);
    final sections = [
      ...section(EntryKind.expense, '지출 분류'),
      ...section(EntryKind.income, '수입 분류'),
    ];
    return [
      ..._title(
        c,
        '카테고리를 연결해주세요',
        '예전 앱의 분류를 지금 쓰는 카테고리에 연결하세요. 없는 분류는 새 카테고리로 만들 수 있어요.',
      ),
      ...sections,
      if (sections.isEmpty)
        _hint(
          c,
          '이 파일에는 분류가 없어서, 모든 내역이 "미분류" 카테고리로 들어가요. 나중에 카테고리 관리에서 정리할 수 있어요.',
        )
      else if (hasBlank)
        _hint(c, '분류가 비어 있는 내역은 "미분류" 카테고리로 들어가요.'),
      if (sections.isNotEmpty)
        _hint(c, '카테고리 이름은 최대 8자라서, 더 긴 분류 이름은 앞 8자만 써요.'),
    ];
  }

  // 4단계: 미리보기
  List<Widget> _previewStep(AppColors c) {
    final parsed = _parsed!;
    final rows = parsed.rows;
    final dates = rows.map((r) => r.date).toList()..sort();
    final newCount = _choices.values
        .expand((m) => m.values)
        .where((id) => id == null)
        .length;
    final linkedCount =
        _choices.values.expand((m) => m.values).length - newCount;
    Widget line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color ?? c.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
    final cats = ref.watch(categoryMapProvider).value ?? const {};
    String categoryLabel(ImportRow r) {
      if (r.categoryRaw.isEmpty) return uncategorizedName;
      final id = _choices[r.kind]?[r.categoryRaw];
      return cats[id]?.name ?? importCategoryName(r.categoryRaw);
    }

    return [
      ..._title(c, '가져올 내용을 확인해주세요'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '${rows.length}건',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '가져올 지출·수입 내역',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      line(
        '기간',
        rows.isEmpty
            ? '-'
            : '${dates.first.substring(0, 7).replaceAll('-', '.')} ~ '
                  '${dates.last.substring(0, 7).replaceAll('-', '.')}',
      ),
      line(
        '카테고리',
        linkedCount + newCount == 0
            ? '미분류로 통일'
            : '기존 $linkedCount개 연결 · $newCount개 신규',
      ),
      line('지출 합계', formatWon(parsed.total(EntryKind.expense))),
      line('수입 합계', formatWon(parsed.total(EntryKind.income))),
      if (parsed.skipped > 0)
        line('읽지 못한 행', '${parsed.skipped}건', color: c.danger),
      if (rows.isEmpty)
        _hint(c, '가져올 수 있는 내역이 없어요. 이전 단계에서 날짜와 금액 열이 맞는지 확인해주세요.')
      else ...[
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 9),
          child: Text(
            '미리보기 (앞 3건)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.textMuted,
            ),
          ),
        ),
        for (final r in rows.take(3))
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    r.date.substring(2).replaceAll('-', '.'),
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    categoryLabel(r),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.description.isEmpty ? '-' : r.description,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${r.kind == EntryKind.income ? '+' : ''}${formatWon(r.amount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    ];
  }

  // 5단계: 완료
  List<Widget> _doneStep(AppColors c) {
    final (expense, income) = _imported!;
    final skipped = _parsed!.skipped;
    return [
      const SizedBox(height: 22),
      const Center(child: Text('✅', style: TextStyle(fontSize: 50))),
      const SizedBox(height: 14),
      const Center(
        child: Text(
          '가져오기 완료!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 9),
      Text(
        '지출 $expense건, 수입 $income건을 가져왔어요.'
        '${skipped > 0 ? '\n($skipped건은 날짜·금액을 읽지 못해 건너뛰었어요)' : ''}'
        '\n홈 화면에서 바로 확인할 수 있어요.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, height: 1.75, color: c.textSecondary),
      ),
    ];
  }
}
