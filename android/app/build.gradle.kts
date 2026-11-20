import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val previewBuild = providers.gradleProperty("piloPreview").orNull == "true"
if (!previewBuild) apply(plugin = "com.google.gms.google-services")
val previewKeyFile = System.getenv("PILO_PREVIEW_KEY_PROPERTIES")
val previewKey = Properties()
if (previewBuild && previewKeyFile != null) file(previewKeyFile).inputStream().use { previewKey.load(it) }
// Preserve the official app's existing, git-ignored signing contract. Never
// substitute a debug/test key when preparing a store update.
val releaseKeyFile = rootProject.file("key.properties")
val releaseKey = Properties()
val hasReleaseKey = !previewBuild && releaseKeyFile.isFile
if (hasReleaseKey) {
    releaseKeyFile.inputStream().use { releaseKey.load(it) }
    for (name in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        require(!releaseKey.getProperty(name).isNullOrBlank()) {
            "Official Android key.properties is missing required signing field: $name"
        }
    }
}

android {
    namespace = "com.papigiras.lab"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Preserve the installed app/Firebase identity for connected builds.
        applicationId = if (previewBuild) "com.papigiras.lab.pruebas" else "com.papigiras"
        manifestPlaceholders["appLabel"] = if (previewBuild) "Pilo Pruebas" else "PapiGiras"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 25
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) create("officialRelease") {
            storeFile = file(releaseKey.getProperty("storeFile"))
            storePassword = releaseKey.getProperty("storePassword")
            keyAlias = releaseKey.getProperty("keyAlias")
            keyPassword = releaseKey.getProperty("keyPassword")
        }
        if (previewBuild && previewKeyFile != null) create("preview") {
            storeFile = file(previewKey.getProperty("storeFile"))
            storePassword = previewKey.getProperty("storePassword")
            keyAlias = previewKey.getProperty("keyAlias")
            keyPassword = previewKey.getProperty("keyPassword")
        }
    }
    buildTypes {
        release {
            // Without the original key this is an unsigned inspection artifact,
            // not an installable/store-ready update.
            signingConfig = when {
                previewBuild && previewKeyFile != null -> signingConfigs.getByName("preview")
                hasReleaseKey -> signingConfigs.getByName("officialRelease")
                else -> null
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
