import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/categories.dart';

void main() {
  group('validateCategoryName', () {
    test('빈 이름·공백만 있는 이름은 안 된다', () {
      expect(validateCategoryName('', []), '이름을 입력해주세요');
      expect(validateCategoryName('   ', []), '이름을 입력해주세요');
    });

    test('같은 종류 안에서 같은 이름은 안 된다(앞뒤 공백 무시)', () {
      expect(validateCategoryName(' 식비', ['식비', '교통']), '이미 있는 이름이에요');
      expect(validateCategoryName('외식', ['식비', '교통']), isNull);
    });

    test('8자를 넘으면 안 된다', () {
      expect(validateCategoryName('가나다라마바사아', []), isNull);
      expect(validateCategoryName('가나다라마바사아자', []), isNotNull);
    });
  });

  test('새 카테고리 이름은 겹치지 않게 번호를 붙인다', () {
    expect(uniqueNewCategoryName(['식비']), '새 항목');
    expect(uniqueNewCategoryName(['새 항목']), '새 항목 2');
    expect(uniqueNewCategoryName(['새 항목', '새 항목 2']), '새 항목 3');
  });
}
