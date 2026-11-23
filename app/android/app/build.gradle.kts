import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Use Flutter's NDK when it is installed; otherwise the newest NDK already in
// the SDK, so a machine with another NDK builds without a download (seen on a
// developer PC where the automatic NDK download failed).
fun pickNdkVersion(wanted: String): String {
    val props = Properties()
    rootProject.file("local.properties").takeIf { it.exists() }
        ?.inputStream()?.use { props.load(it) }
    val sdk = props.getProperty("sdk.dir")
        ?: System.getenv("ANDROID_SDK_ROOT")
        ?: System.getenv("ANDROID_HOME")
        ?: return wanted
    val installed = File(sdk, "ndk").listFiles()
        ?.filter { File(it, "source.properties").exists() }
        ?.map { it.name }
        .orEmpty()
    if (installed.isEmpty() || wanted in installed) return wanted
    fun parts(v: String) = v.split('.').map { it.toIntOrNull() ?: 0 }
    val newest = installed.maxWithOrNull { a, b ->
        val pa = parts(a)
        val pb = parts(b)
        (0 until maxOf(pa.size, pb.size))
            .map { (pa.getOrElse(it) { 0 }).compareTo(pb.getOrElse(it) { 0 }) }
            .firstOrNull { it != 0 } ?: 0
    } ?: return wanted
    logger.lifecycle("Storize: NDK $wanted not installed, using $newest")
    return newest
}

android {
    namespace = "com.amr905.storize"
    compileSdk = 37
    ndkVersion = pickNdkVersion(flutter.ndkVersion)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs java.time on older APIs (T-022).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.amr905.storize"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        resValues = true
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Storize Dev")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Storize")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
