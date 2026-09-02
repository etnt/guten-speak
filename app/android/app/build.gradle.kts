import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config is read from android/key.properties (created by CI
// from secrets, and gitignored). Absent locally, we fall back to debug keys.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "se.kruskakli.guten_speak"
    // The Pixel 10 Pro runs Android 17 (API 37); audio_service builds against
    // SDK 37. Flutter's default (36) is too low, so pin to 37.
    // Requires a local platforms/android-37 in the Android SDK (symlink
    // android-36 → android-37 if the platform package isn't published yet).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "se.kruskakli.guten_speak"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Default launcher label; overridden per flavor below.
        manifestPlaceholders["appName"] = "Guten-Speak"

        // Restrict to arm64-v8a for now (physical Pixel 10 Pro + Apple-silicon
        // emulators). Widen this list before a public release.
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    // Two release tracks that can be installed side by side: `prod` is the
    // store identity; `beta` carries a distinct application id (.beta suffix)
    // and its own launcher label so internal test builds never clobber prod.
    // Flutter commands now require `--flavor prod` or `--flavor beta`.
    flavorDimensions += "track"
    productFlavors {
        create("prod") {
            dimension = "track"
        }
        create("beta") {
            dimension = "track"
            applicationIdSuffix = ".beta"
            versionNameSuffix = "-beta"
            manifestPlaceholders["appName"] = "Guten-Speak Beta"
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real release keystore when available (CI), otherwise the
            // debug keys so `flutter build apk --release` still works locally.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Name each output APK `guten-speak-<flavor>-<version>-<abi>.apk` (abi is
// `universal` for a single fat APK; the real ABI name when built with
// `flutter build apk --split-per-abi`). versionName already carries the
// `-beta` suffix for the beta flavor.
android.applicationVariants.all {
    val variant = this
    outputs.all {
        val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
        val abi = output.getFilter("ABI") ?: "universal"
        output.outputFileName =
            "guten-speak-${variant.flavorName}-${variant.versionName}-$abi.apk"
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
