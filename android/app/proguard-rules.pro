# 영수증 글자 인식(google_mlkit_text_recognition) 플러그인은 중국어·데바나가리·일본어
# 인식기 클래스를 참조하지만, 앱에는 한국어 모델만 넣는다(build.gradle.kts).
# 쓰지 않는 언어의 클래스가 없다는 R8 경고를 무시한다(호출되지 않는다).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
