import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
val releaseStore = signingProperties.getProperty("storeFile")
val releaseAlias = signingProperties.getProperty("keyAlias")
val releaseStorePassword = signingProperties.getProperty("storePassword")
val releaseKeyPassword = signingProperties.getProperty("keyPassword")
val hasReleaseKey = listOf(releaseStore, releaseAlias, releaseStorePassword, releaseKeyPassword).all { !it.isNullOrBlank() }
require(!signingFile.exists() || hasReleaseKey) { "android/key.properties is incomplete; release signing values are required." }
if (!hasReleaseKey) logger.warn("TACTIX: No private release key configured. This APK will use the debug key and is not for distribution.")

android {
    namespace = "com.example.ai_trainer_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ai_trainer_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                storeFile = file(releaseStore!!)
                keyAlias = releaseAlias
                storePassword = releaseStorePassword
                this.keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Prefer the local private key; debug signing is a development-only fallback.
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
