import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/data/import_reader.dart';

import '../helpers.dart';
import 'pump.dart';

void main() {
  Future<void> withData(AppDatabase db) async {
    await addEntry(db, date: '2026-11-07', categoryId: 1, amount: 9000);
    await addEntry(db, date: '2026-10-20', categoryId: 2, amount: 1500);
  }

  Future<void> startExport(WidgetTester tester) async {
    await openTab(tester, '설정');
    await tap(tester, find.text('엑셀 파일로 내보내기'));
  }

  testWidgets('이번 달을 고르면 그 기간의 내역만 폴더에 저장한다', (tester) async {
    String? name;
    Uint8List? bytes;
    await pumpApp(
      tester,
      setup: withData,
      fileSaver: (n, b) async {
        name = n;
        bytes = b;
        return true;
      },
    );
    await startExport(tester);
    expect(find.text('11.1 ~ 11.30'), findsOneWidget);
    await tap(tester, find.text('이번 달 (11월)'));
    await tap(tester, find.text('폴더에 저장'));

    expect(find.text('✓ 엑셀 파일을 저장했어요'), findsOneWidget);
    expect(name, 'gagyebu-entries-20261101-20261130.xlsx');
    expect(readImportFile(name!, bytes!).rows, hasLength(1));
  });

  testWidgets('전체 기간을 다른 앱으로 보낸다', (tester) async {
    Uint8List? shared;
    await pumpApp(
      tester,
      setup: withData,
      fileSharer: (_, b) async {
        shared = b;
        return true;
      },
    );
    await startExport(tester);
    await tap(tester, find.text('전체 기간'));
    await tap(tester, find.text('다른 앱으로 보내기'));

    expect(find.text('✓ 엑셀 파일을 보냈어요'), findsOneWidget);
    expect(readImportFile('a.xlsx', shared!).rows, hasLength(2));
  });

  testWidgets('내역이 없는 기간이면 알려주고 파일을 만들지 않는다', (tester) async {
    await pumpApp(tester);
    await startExport(tester);
    await tap(tester, find.text('지난달 (10월)'));
    expect(find.text('이 기간에는 내역이 없어요'), findsOneWidget);
    expect(find.text('폴더에 저장'), findsNothing);
  });

  testWidgets('기간 직접 고르기: 날짜 범위 창에서 고른 기간을 내보낸다', (tester) async {
    String? name;
    await pumpApp(
      tester,
      setup: withData,
      fileSaver: (n, _) async {
        name = n;
        return true;
      },
    );
    await startExport(tester);
    await tap(tester, find.text('기간 직접 고르기'));
    expect(find.text('내보낼 기간'), findsOneWidget);
    await tap(tester, find.text('선택'));
    await tap(tester, find.text('폴더에 저장'));
    expect(name, 'gagyebu-entries-20261101-20261130.xlsx', reason: '처음엔 이번 달');
  });
}
