# 가계부

예산을 먼저 정하고, 그 안에서 지출을 관리하는 한국어 가계부 앱 (Flutter, Android 우선).

## 최신 테스트 빌드 받기
코드를 올릴 때마다 GitHub Actions가 검사·테스트 후 APK를 만들어
**Releases → "최신 테스트 빌드"(태그 `dev-latest`)**에 올린다.

- 폰: https://github.com/Kal-Moon/Budget-book-application/releases/tag/dev-latest 에서 `gagyebu-dev.apk`를 받아 설치
- 설정 화면 아래쪽의 `ver.1.0.0+N`의 N이 Releases 제목의 빌드 번호와 같으면 최신 빌드다.

## PC에서 실행
```
flutter pub get
flutter run            # USB로 연결한 폰 또는 에뮬레이터
flutter test           # 자동 테스트
```

DB 코드(`lib/data/database.g.dart`)는 생성 파일이다. `database.dart`를 바꾸면 다시 만든다.
```
dart run build_runner build --delete-conflicting-outputs
```

작업 규칙과 확정 사양은 [CLAUDE.md](CLAUDE.md)를 본다.
