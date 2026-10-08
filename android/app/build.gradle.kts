import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Phone Auth (customer OTP login) - reads google-services.json
    // in this same directory.
    id("com.google.gms.google-services")
}

// Release signing comes from android/key.properties, which is git-ignored
// and never committed - see android/key.properties.example for the format.
// Falls back to the debug keystore (so `flutter run --release` still works
// out of the box) when that file doesn't exist, e.g. on a fresh checkout
// before a real release keystore has been provisioned.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Google Maps SDK for Android requires its API key declared natively in
// AndroidManifest.xml (unlike the Geocoding API, which is a plain HTTP
// call from Dart and reads GOOGLE_GEOCODING_API_KEY via flutter_dotenv at
// runtime). Rather than duplicating the key in a second place, read it
// out of the same root .env file at build time and inject it via a
// manifest placeholder - see the meta-data entry in AndroidManifest.xml.
// Same key as GOOGLE_GEOCODING_API_KEY: one Google Cloud API key with
// both the Geocoding API and Maps SDK for Android enabled works for both.
val dotEnvFile = rootProject.file("../.env")
var googleMapsApiKey = ""
if (dotEnvFile.exists()) {
    dotEnvFile.forEachLine { line ->
        val trimmed = line.trim()
        if (trimmed.startsWith("GOOGLE_GEOCODING_API_KEY=")) {
            googleMapsApiKey = trimmed.substringAfter("=").trim()
        }
    }
}

android {
    namespace = "com.gruhinifoods.gruhini_foods"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gruhinifoods.gruhini_foods"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigning) {
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
            // Real release keystore once android/key.properties exists (see
            // above); until then, falls back to the debug keystore so
            // `flutter run --release` / `flutter build apk --debug` keep
            // working on a fresh checkout. A debug-signed build must never
            // be uploaded to the Play Store.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
