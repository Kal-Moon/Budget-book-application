import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../entry/category_picker_sheet.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';

/// 카테고리의 내역 목록을 연다(합치기·삭제 전에 무엇이 들어 있는지 확인용).
Future<void> openCategoryEntries(BuildContext context, Category category) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryEntriesScreen(category: category),
      ),
    );

/// 한 카테고리의 내역(최신순). 카테고리 칩을 누르면 그 내역만 다른 카테고리로 옮긴다.
class CategoryEntriesScreen extends ConsumerWidget {
  const CategoryEntriesScreen({super.key, required this.category});

  final Category category;

  Future<void> _move(BuildContext context, WidgetRef ref, Entry entry) async {
    final id = await showCategoryPicker(
      context,
      kind: category.kind,
      selectedId: category.id,
    );
    if (id == null || id == category.id || !context.mounted) return;
    await ref.read(databaseProvider).setEntryCategory(entry.id, id);
    final target = ref.read(categoryMapProvider).value?[id];
    if (context.mounted && target != null) {
      showToast(context, "'${target.name}'(으)로 옮겼어요");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final all = ref.watch(allEntriesProvider).value ?? const <Entry>[];
    final entries = all.where((e) => e.categoryId == category.id).toList()
      ..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));

    return Scaffold(
      appBar: AppBar(title: Text("'${category.name}' 내역 ${entries.length}건")),
      body: entries.isEmpty
          ? Center(
              child: Text(
                '이 카테고리에는 내역이 없어요.',
                style: TextStyle(color: c.textMuted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  '오른쪽 카테고리를 누르면 그 내역만 다른 카테고리로 옮길 수 있어요.',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
                const SizedBox(height: 10),
                for (final e in entries)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(13, 9, 8, 9),
                    decoration: BoxDecoration(
                      color: c.surface2,
                      border: Border.all(color: c.border, width: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  if (e.description.isNotEmpty) e.description,
                                  if (e.place.isNotEmpty) e.place,
                                ].join(' · ').ifEmpty('(내용 없음)'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${e.date.replaceAll('-', '.')} ${e.time} · '
                                '${formatWon(e.amount)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Color(category.color).withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _move(context, ref, e),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                '${category.icon} ${category.name} ▾',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// 시트 안에 넣는 "내역 N건 보기 ›" 줄. 건수는 내역이 옮겨지면 바로 바뀐다.
class CategoryEntriesLink extends ConsumerWidget {
  const CategoryEntriesLink({super.key, required this.category, this.label});

  final Category category;

  /// 앞에 붙는 말(예: "합치기 전에").
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref
            .watch(allEntriesProvider)
            .value
            ?.where((e) => e.categoryId == category.id)
            .length ??
        0;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => openCategoryEntries(context, category),
        icon: const Icon(Icons.list_alt, size: 18),
        label: Text('${label == null ? '' : '$label '}내역 $count건 보기 ›'),
      ),
    );
  }
}
