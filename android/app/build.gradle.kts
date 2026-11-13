plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mybudgetapp.gagyebu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mybudgetapp.gagyebu"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 테스트 빌드 전용 서명 키(레포에 포함). 어느 PC·CI에서 빌드해도 같은 키로 서명되어
    // 새 APK가 기존 앱 위에 덮어 설치되고 데이터가 유지된다.
    // Play 스토어 출시 때는 별도의 업로드 키를 쓰고, 그 키는 커밋하지 않는다.
    signingConfigs {
        create("dev") {
            storeFile = file("dev.keystore")
            storePassword = "gagyebu-dev"
            keyAlias = "dev"
            keyPassword = "gagyebu-dev"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("dev")
        }
        release {
            signingConfig = signingConfigs.getByName("dev")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 지문·얼굴 인식 창이 쓰는 AppCompat 테마(styles.xml의 Theme.AppCompat.*).
    implementation("androidx.appcompat:appcompat:1.7.0")
    // 영수증 글자 인식(ML Kit)의 한국어 모델. 폰 안에서만 인식하고 인터넷을 쓰지 않는다.
    // 플러그인은 기본으로 라틴 문자만 넣으므로 한국어 모델을 따로 넣는다.
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
}
