# 가계부 앱 — Claude Code 인계 문서

## 1. 목표와 작업 방식
- 한국어 모바일 가계부 앱. 컨셉: **"예산을 먼저 정하고, 그 안에서 지출을 관리"**.
- 최종 목표: **Google Play 스토어 출시 + 리뷰 확보**.
- 사용자는 실제 Android 폰에서 테스트하고 번호 매긴 피드백을 준다.
- 제안/아이디어는 먼저 의견·분석만 말하고, 사용자가 "개발해줘/반영해줘"라고 할 때만 개발한다.
- 모든 UI 문구·대화는 한국어.

## 2. 기술 스택 / 구조
- 단일 파일 바닐라 HTML/CSS/JS (`index.html`, 약 2,200줄), localStorage 키 `budget_app_state_v1`.
- 라이브러리(현재 CDN): Chart.js 4.4.1, SheetJS xlsx 0.18.5, Tabler Icons, Google Fonts(Gothic A1, Gaegu).
- Capacitor 8.5.0 래핑: appId `com.mybudgetapp.gagyebu`, appName `가계부`, webDir `www`.
- 프로젝트: `gagyebu-app/` (`www/`, `android/`, `capacitor.config.ts`, `package.json`, `README.md`).
- Android: minSdk 24, compile/targetSdk 36, versionCode 1. colors.xml 직접 생성(#378ADD), 런처 아이콘/스플래시 생성 완료.
- 업데이트 절차: `www/index.html` 교체 → `npx cap sync android` → Android Studio Run.
- APP_VERSION `'2026.08.20-1'`. `www`본은 `if ('serviceWorker' in navigator && !window.Capacitor)`로 SW 등록 차단.
- PWA 파일(manifest, service-worker, _headers)은 WebAPK 업데이트 문제로 폐기, 네이티브 APK로 전환.

## 3. 데이터 모델 / 핵심 함수
- `budgetHistory['YYYY-MM'] = {mode, total, catBudgets:{catId:amt}}`
- `getTotalBudget(mk)`, `getCatBudget(id, mk)`, `commitCurrentMonthBudget()`, `isOverBudget(spent,budget)`(임계값 반영)
- 과거 달 예산은 0으로 표시, 설정은 항상 현재 실제 달 기준 편집, 0 예산 허용.
- 네이티브 `confirm()` 금지 → `openGenericConfirm(title, descHtml, onConfirm, label)` 사용.
- 주요 함수: `saveState/loadState`, `showScreen`, `renderHome`, `renderDonutPane`, `openInput/openEdit/openEditIncome/doSaveExpense/saveExpense/closeInput`, 카테고리 관리(`renderCatManageList`, `openIconPicker`, `deleteCatFromSettings`, `openCatDeleteFlow`, `commitCatDelete`), 가져오기(`openImportFlow`, `importNext`, `handleFileSelect`, `guessColumn`, `buildColumnMappingUI`, `readMappingSelects`, `parseImportRows`, `commitImport`), 세부 설정(`renderDetailSettings`, `toggleMistapProtection`, `toggleExitConfirm`, `renderCatColorList`, `setFontStyle/setFontSize/applyFontPrefs`, `setBudgetThreshold`, PIN: `openPinFlow/applockSubmit/completeInit`).
- 글자 크기: 루트 font-size + rem (`FONT_SIZE_PX={small:15,medium:16,large:18}`), zoom 사용 금지.
- 레이아웃: `.app-shell{height:100dvh;overflow:hidden}`, 내부 스크롤 영역 `min-height:0`, `overscroll-behavior`로 당겨서 새로고침 차단.

## 4. 확정된 제품 사양
**용어**: 총 예산으로 정하기 / 항목별로 정하기, 지난달 예산 자동 적용, 차액(절약 X), 구매처(수입은 출처), 입력 제목 "내역 입력", 하단 탭 홈/입력/분석/설정, "세부 설정", "실수 방지".

**온보딩 5단계**: 환영 → 예산 방식 → 카테고리 → 금액 → 검토. 뒤로가기 `‹`(텍스트 문자). 건너뛰기=전체 스킵 + 확인창 → 예산 0으로 홈 진입(설정에서 지정 안내). 금액 0으로도 진행 가능.

**홈**: 이번 달 지출/남은 금액, 진행바, 수입/지출/차액 줄(토글), 카테고리 칩, 필터(전체/지출/수입 + 카테고리), 검색(내용+구매처), 날짜 드릴다운(기본 일 단위, 연/월 버튼), 날짜별 그룹 리스트, 메모 비면 카테고리명 흐리게, FAB 없음, 하단 네비 고정.

**입력 순서**: 날짜/시간 → 지출/수입 → 카테고리 팝업 → 금액 → 구매처 → 내역 → 메모. 자동 다음 이동, 카테고리별 자동완성, [저장][취소] 하단 고정, 예산 초과 경고.

**카테고리 관리**: 추가/이름/예산/아이콘 72종 선택/삭제(내역 이동 선택). 입력 화면에서도 관리 가능. 색상 12종(아이콘 배경·점·차트에 적용, 글자색 X — 설명 문구에 명시).

**분석**: 도넛(카테고리→해당 월 내역), 추이 3/6/12개월(월 클릭→그 달 도넛), 연간(카테고리→월별 막대), 수입/지출/차액 줄(홈과 별도 토글), 강조색 12종(기본 6 + 파스텔 6, 미리보기).

**세부 설정**: 저장/취소 확인, 뒤로가기 종료 확인, 카테고리 색상, 글꼴, 글자 크기, 임계값 80/90/100, 분석 강조색, PIN 잠금. 기본값은 모두 꺼짐/기본.

**다른 앱 가져오기**: 편한가계부 xlsx — A날짜 B자산 C분류 D소분류 E내용 F KRW G수입/지출 H메모 I금액 J화폐 K자산. 금액은 항상 양수 + 별도 유형 열.

## 5. 과거 버그와 교훈 (재발 주의)
- 네비바 스크롤/페이지 늘어남 → 앱 셸 100dvh 고정.
- `confirm()` 조용히 무시됨 → 커스텀 모달.
- 아이콘 폰트 의존 뒤로가기 버튼 안 보임 → 일반 문자.
- 가져오기: "수입/지출" 열이 금액으로 오인 → 정확 일치 우선 매칭, 유형 기본 "별도 열", 검증 전에 `readMappingSelects()` 호출.
- 데이터 초기화 후 가져오기 재발 이력 있음 → 회귀 테스트 필수.
- PWA 업데이트 미반영(WebAPK) → 네이티브 전환.
- 검증은 headless Chrome(puppeteer-core)/jsdom 사용.

## 6. 현재 환경 상태
- Windows, Android Studio Quail 3 (2026.1.3). SDK는 사용자 지정 경로(`D:\Android Studio\SDK`), 관리자 권한 실행으로 쓰기 권한 해결.
- `android` 폴더를 열었고 "Please Select Gradle JVM"에서 **Use JVM 21** 선택 안내(Gradle 8.14.3은 JVM 8–24만 지원, JVM 25 불가).
- 다음: Gradle Sync 성공 확인 → 폰 개발자 옵션/USB 디버깅 → ▶ Run. 에뮬레이터 컴포넌트 경고는 무시(실기기 테스트).
- 권장: 프로젝트를 SDK 폴더 밖(예: `D:\gagyebu-app`)으로 이동.

## 7. TODO (우선순위 순)
1. Gradle Sync/실기기 실행 확인.
2. CDN 라이브러리(Chart.js, SheetJS, Tabler, Google Fonts) 로컬 번들 → 오프라인 동작.
3. 뒤로가기/종료 확인을 Capacitor `@capacitor/app` backButton으로 재작업 (현재 `history.pushState`+`popstate` 방식).
4. 데이터 내보내기/백업 (앱 삭제 시 localStorage 소실).
5. 패키지 ID 확정, 실기기 회귀 테스트.
6. AdMob 배너(기능 방해 없는 수준), 개인정보처리방침 페이지.
7. 서명된 릴리스 AAB, Play Console 비공개 테스트(신규 개인 계정: 테스터 12명 × 14일), 개발자 등록 $25.

**보류 아이디어**: 지난 달 예산 수정, 자산 기능, 카테고리 순서 드래그, 사진 첨부, 금액 단축 버튼, 주 시작 요일, 일일 알림, 자동 백업, 앱 이름 확정(미정).

## 8. Claude Code 첫 프롬프트 예시
> 이 CLAUDE.md를 읽고 `gagyebu-app/` 프로젝트를 이어서 작업해줘. 먼저 `www/index.html`의 CDN 의존성을 로컬 번들로 바꾸고, 뒤로가기를 Capacitor backButton으로 재작업해줘. 변경 전 계획을 먼저 보여주고, 내가 "개발해줘"라고 하면 진행해.
