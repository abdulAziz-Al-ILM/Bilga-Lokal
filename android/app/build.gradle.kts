import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val bilgaKeys = Properties()
val bilgaKeyFile = rootProject.file("key.properties")
if (bilgaKeyFile.exists()) {
    bilgaKeyFile.inputStream().use { bilgaKeys.load(it) }
}
val bilgaHasKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    .all { !bilgaKeys.getProperty(it).isNullOrBlank() }
// Explicit opt-in for USB testing with separate Android UID, storage and keys.
// The default/production application ID and signing configuration stay intact.
val bilgaReview = providers.gradleProperty("bilgaReview").orNull == "true"


android {
    if (bilgaReview && providers.gradleProperty("bilgaReviewProfileTest").orNull == "true") {
        testBuildType = "profile"
    }
    namespace = "com.ilmmizan.bilga"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    // The independent speech executable is launched from the signed native directory.
    packaging.jniLibs.useLegacyPackaging = true

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ilmmizan.bilga"
        if (bilgaReview) applicationIdSuffix = ".review"
        manifestPlaceholders["bilgaAppLabel"] = if (bilgaReview) "Bilga Review" else "Bilga"
        manifestPlaceholders["bilgaTestTarget"] = if (bilgaReview) "com.ilmmizan.bilga.review" else "com.ilmmizan.bilga"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        testInstrumentationRunner = "com.ilmmizan.bilga.NotesWidgetChecks"
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = providers.gradleProperty("bilga.versionCode").orNull?.toIntOrNull() ?: flutter.versionCode
        versionName = providers.gradleProperty("bilga.versionName").orNull ?: flutter.versionName
    }

    signingConfigs {
        getByName("debug") {
            if (bilgaReview) {
                storeFile = rootProject.file("../.bilga-tools/review-signing/debug.keystore")
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
        create("release") {
            if (bilgaHasKeys) {
                keyAlias = bilgaKeys.getProperty("keyAlias")
                keyPassword = bilgaKeys.getProperty("keyPassword")
                storeFile = file(bilgaKeys.getProperty("storeFile"))
                storePassword = bilgaKeys.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    // Same SQLCipher artifact already used by sqflite_sqlcipher; no second engine.
    implementation("net.zetetic:sqlcipher-android:4.10.0@aar")
    implementation("androidx.sqlite:sqlite:2.5.2") // Same version as sqflite_sqlcipher.
}

// Debug builds stay available; release must never fall back to a debug key.
tasks.configureEach {
    if (name == "preReleaseBuild") {
        doFirst {
            if (bilgaReview) throw GradleException("Bilga Review is restricted to debug testing.")
            if (!bilgaHasKeys) {
                throw GradleException("Bilga: android/key.properties ni sozlang. CHIQARISH.md ni o‘qing.")
            }
        }
    }
}
