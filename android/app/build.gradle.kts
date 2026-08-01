plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

configurations.all {
    resolutionStrategy {
        force("androidx.appcompat:appcompat:1.6.1")
    }
}

android {
    namespace = "com.anything.anything"
    compileSdk = flutter.compileSdkVersion
    // speech_to_text (and the rest of the current plugin set) requests
    // 28.2.13676358, but the locally installed copy of that NDK is a
    // corrupted/incomplete download (missing source.properties — see
    // docs/audit/V2_SECURITY_AUDIT.md / M2 Android build note). Staying on
    // 27.0.12077973, which IS a valid, verified-present install, until a
    // clean 28.2.13676358 is re-downloaded outside this repo's scope.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.anything.anything"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
