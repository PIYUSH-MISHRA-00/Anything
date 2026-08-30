import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing (IS-P01) ────────────────────────────────────────────────
//
// WHAT WAS WRONG, MEASURED BY THE IS-P01 PRODUCT AUDIT:
//
//   The release build type signed with `signingConfigs.getByName("debug")`.
//   Google Play REJECTS debug-signed uploads outright, so no artifact this
//   repository could produce was ever publishable. `flutter build apk
//   --release` was never run by CI or by any of milestones R1-R62, so the
//   defect was invisible for the project's entire history.
//
// `android/key.properties` is gitignored and absent from a fresh clone, which
// is deliberate: a contributor building locally keeps working with debug
// signing, and only a release build on a machine holding the real keystore
// produces a publishable artifact. See docs/RELEASE_GUIDE.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

configurations.all {
    resolutionStrategy {
        force("androidx.appcompat:appcompat:1.6.1")
    }
}

android {
    namespace = "com.anything.anything"
    // PINNED IN IS-P29, previously `flutter.compileSdkVersion` (36).
    //
    // compileSdk must be >= targetSdk, and targetSdk is pinned at 37 below.
    // Flutter 3.44 still defaults to 36, so inheriting it would cap the
    // target one level below the newest stable API.
    compileSdk = 37
    // speech_to_text requests 28.2.13676358. P18 re-installed a complete
    // NDK 28.2.13676358 (source.properties present) so the project pins the
    // plugin-required version rather than suppressing the mismatch.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // A lint check inside a third-party plugin (file_picker) crashes Android's
    // lint tool during `lintVitalAnalyzeRelease` with a NoClassDefFoundError in
    // NonNullableMutableLiveDataDetector. lint runs on release builds but not
    // debug — which is why debug builds pass and release did not. Lint is not a
    // Play requirement, so it must never block a signed release artifact.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.anything.anything"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion

        // PINNED IN IS-P04, previously `flutter.targetSdkVersion`.
        //
        // Google Play enforces a targetSdk floor and raises it on a schedule.
        // Inheriting the value means a Flutter upgrade can move it silently in
        // either direction -- including below the floor, which fails an upload
        // with no local signal. Pinning makes the number a reviewable decision
        // in a diff.
        //
        // 37 = Android 17, the newest stable API level (IS-P29).
        //
        // Play's rule is "within one year of the latest Android release", and
        // it bites on a yearly deadline: 31 Aug 2026 needs >= 36, 31 Aug 2027
        // needs >= 37. Targeting the floor buys twelve months and another
        // warning mail; targeting the newest level buys two years, which is
        // why this is 37 rather than the 36 the deadline demands.
        //
        // Behaviour changes carried by the 35 -> 37 move: API 36 makes
        // edge-to-edge mandatory (no opt-out) and API 37 keeps it that way.
        // Last on-device verification was API 35 (moto g45 5G, IS-P04);
        // re-verify on device after this bump.
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real release signing when a keystore is configured; debug signing
            // otherwise, so a fresh clone still builds. A debug-signed artifact
            // is NOT publishable — RELEASE_GUIDE.md covers keystore setup, and
            // the release workflow refuses to publish without one.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 with the Flutter/Android defaults plus this project's rules.
            // Measured effect is recorded in PLAYSTORE_READINESS.md.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
