plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.gutenspeak.guten_speak_poc"
    // The Pixel 10 Pro runs Android 17 (API 37) and the transitive
    // permission_handler_android plugin requires compiling against SDK 37.
    // Flutter's default (36) is too low, so pin compileSdk to 37 here.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gutenspeak.guten_speak_poc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // PoC targets a physical Pixel 10 Pro (Tensor G5 = arm64-v8a) and
        // Apple-silicon emulators (also arm64-v8a). Restricting to this single
        // ABI keeps the build lean: sherpa_onnx otherwise bundles native libs
        // for armeabi-v7a / x86 / x86_64 too. Widen this list before shipping.
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
