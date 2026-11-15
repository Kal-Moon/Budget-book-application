# 영수증 글자 인식(google_mlkit_text_recognition) 플러그인은 중국어·데바나가리·일본어
# 인식기 클래스를 참조하지만, 앱에는 한국어 모델만 넣는다(build.gradle.kts).
# 쓰지 않는 언어의 클래스가 없다는 R8 경고를 무시한다(호출되지 않는다).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**

# ML Kit(글자 인식)은 실행 중에 부품을 이름·리플렉션으로 찾는다. R8이 내부 코드를 지우거나
# 이름을 바꾸자 인식기를 만들 때 NullPointerException(getClass() on null)으로 실패했다(빌드 24·25).
# ML Kit과 그 부품 등록(Firebase components) 코드는 그대로 둔다.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
