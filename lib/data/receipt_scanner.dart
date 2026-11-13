import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/receipt.dart';

/// 영수증 사진을 어디서 가져올지.
enum ReceiptSource { camera, gallery }

/// 사진을 고르고 글자를 읽어 줄 조각들을 돌려준다. 사진을 고르지 않으면 null.
/// 테스트에서는 [receiptScannerProvider]를 바꿔 끼운다.
typedef ReceiptScanner = Future<List<OcrLine>?> Function(ReceiptSource source);

final receiptScannerProvider = Provider<ReceiptScanner>(
  (ref) => _scanWithMlKit,
);

/// 폰 안에서만 읽는다(ML Kit, 한국어 모델). 사진은 읽은 뒤 바로 지우고 어디에도 보내지 않는다.
Future<List<OcrLine>?> _scanWithMlKit(ReceiptSource source) async {
  final photo = await ImagePicker().pickImage(
    source: source == ReceiptSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    // 글자를 읽기에 충분한 크기로 줄여서 빠르게 처리한다.
    maxWidth: 2000,
    maxHeight: 2000,
    requestFullMetadata: false,
  );
  if (photo == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(photo.path),
    );
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          OcrLine(
            line.text,
            line.boundingBox.left,
            line.boundingBox.top,
            line.boundingBox.right,
            line.boundingBox.bottom,
          ),
    ];
  } finally {
    await recognizer.close();
    // image_picker가 앱 임시 폴더에 만든 사본이다(원본 사진은 그대로).
    try {
      await File(photo.path).delete();
    } on FileSystemException {
      // 이미 지워졌으면 그만.
    }
  }
}
