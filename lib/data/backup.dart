import 'dart:convert';
import 'dart:typed_data';

import 'database.dart';

/// 백업 파일(JSON) 형식.
/// {
///   "app": "gagyebu", "format": 1, "schemaVersion": 1, "createdAt": "...",
///   "tables": { 테이블 이름: [행, ...] },   // DB를 통째로
///   "settings": { 설정 이름: 값 }           // 설정 화면의 선택값을 통째로
/// }
/// 앱 잠금(PIN·복구 질문)은 보안 저장소에 있고 백업에 넣지 않는다.
const backupAppId = 'gagyebu';
const backupFormat = 1;

/// 백업 파일을 읽을 수 없을 때. [message]는 사용자에게 그대로 보여준다.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 읽어 들인 백업 파일. 복원하기 전에 내용을 요약해서 보여줄 때도 쓴다.
class BackupFile {
  const BackupFile({
    required this.createdAt,
    required this.tables,
    required this.settings,
  });

  final DateTime createdAt;
  final Map<String, List<Map<String, Object?>>> tables;
  final Map<String, Object?> settings;

  int get entryCount => tables['entries']?.length ?? 0;
  int get categoryCount => tables['categories']?.length ?? 0;
}

/// 지금 데이터로 백업 파일 내용을 만든다.
Future<Uint8List> createBackup(
  AppDatabase db, {
  required Map<String, Object> settings,
  required DateTime now,
}) async {
  final json = {
    'app': backupAppId,
    'format': backupFormat,
    'schemaVersion': db.schemaVersion,
    'createdAt': now.toIso8601String(),
    'tables': await db.exportAllTables(),
    'settings': settings,
  };
  return utf8.encode(const JsonEncoder.withIndent(' ').convert(json));
}

/// 백업 파일을 읽고 형식을 검사한다. 이 앱의 백업이 아니면 [BackupException].
BackupFile parseBackup(Uint8List bytes, {required int schemaVersion}) {
  const notBackup = BackupException('이 앱에서 만든 백업 파일이 아니에요');
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw notBackup;
  }
  if (json is! Map<String, Object?> || json['app'] != backupAppId) {
    throw notBackup;
  }
  final format = json['format'];
  final version = json['schemaVersion'];
  if (format is! int || version is! int) throw notBackup;
  if (format > backupFormat || version > schemaVersion) {
    throw const BackupException('더 새 버전의 앱에서 만든 백업이에요. 앱을 업데이트한 뒤 복원해주세요');
  }
  final createdAt = DateTime.tryParse('${json['createdAt']}');
  final tables = json['tables'];
  final settings = json['settings'];
  if (createdAt == null ||
      tables is! Map<String, Object?> ||
      settings is! Map<String, Object?>) {
    throw notBackup;
  }
  final rows = <String, List<Map<String, Object?>>>{};
  for (final MapEntry(:key, :value) in tables.entries) {
    if (value is! List || value.any((r) => r is! Map<String, Object?>)) {
      throw notBackup;
    }
    rows[key] = value.cast<Map<String, Object?>>();
  }
  return BackupFile(createdAt: createdAt, tables: rows, settings: settings);
}

/// 백업의 기록으로 DB를 통째로 바꾼다. 잘못된 내용이면 아무것도 바꾸지 않고
/// [BackupException].
Future<void> restoreRecords(AppDatabase db, BackupFile backup) async {
  try {
    await db.replaceAllTables(backup.tables);
  } catch (_) {
    throw const BackupException('백업 파일 내용이 손상돼서 복원할 수 없어요');
  }
}

/// 저장할 파일 이름: gagyebu-backup-20261111-1030.json
String backupFileName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'gagyebu-backup-${now.year}${two(now.month)}${two(now.day)}'
      '-${two(now.hour)}${two(now.minute)}.json';
}
