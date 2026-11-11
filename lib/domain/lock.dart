import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PIN 자릿수.
const pinLength = 4;

/// 백그라운드에 이 시간보다 오래 있다가 돌아오면 다시 잠근다
/// (파일 선택처럼 잠깐 다녀오는 건 잠그지 않는다).
const relockAfter = Duration(minutes: 1);

/// 비밀번호 찾기 질문을 이만큼 틀리면 [answerLockout] 동안 다시 시도할 수 없다.
const maxAnswerAttempts = 5;
const answerLockout = Duration(minutes: 5);

/// 새 소금값(해시마다 다르게 섞는 임의 값).
String newSalt([Random? random]) {
  final r = random ?? Random.secure();
  return base64Url.encode([for (var i = 0; i < 16; i++) r.nextInt(256)]);
}

/// PIN·답을 저장할 때 쓰는 해시. 원래 값은 어디에도 저장하지 않는다.
String hashSecret(String value, String salt) {
  List<int> bytes = utf8.encode('$salt:$value');
  for (var i = 0; i < 2000; i++) {
    bytes = sha256.convert(bytes).bytes;
  }
  return base64Url.encode(bytes);
}

/// 질문의 답 비교용 정리: 띄어쓰기와 영문 대소문자를 무시한다.
/// ('초 코'와 '초코', 'Coco'와 'coco'는 같은 답)
String normalizeAnswer(String answer) =>
    answer.replaceAll(RegExp(r'\s+'), '').toLowerCase();
