plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase configuration is environment-specific. Local/offline builds stay
// buildable without the file; CI and store builds must provide the matching
// google-services.json and therefore activate this plugin.
if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}

val releaseSigningValues = mapOf(
    "RALLYMATE_ANDROID_KEYSTORE_PATH" to
        providers.environmentVariable("RALLYMATE_ANDROID_KEYSTORE_PATH").orNull,
    "RALLYMATE_ANDROID_KEYSTORE_PASSWORD" to
        providers.environmentVariable("RALLYMATE_ANDROID_KEYSTORE_PASSWORD").orNull,
    "RALLYMATE_ANDROID_KEY_ALIAS" to
        providers.environmentVariable("RALLYMATE_ANDROID_KEY_ALIAS").orNull,
    "RALLYMATE_ANDROID_KEY_PASSWORD" to
        providers.environmentVariable("RALLYMATE_ANDROID_KEY_PASSWORD").orNull,
)
val hasAnyReleaseSigningValue = releaseSigningValues.values.any { !it.isNullOrBlank() }
val hasCompleteReleaseSigning = releaseSigningValues.values.all { !it.isNullOrBlank() }

check(!hasAnyReleaseSigningValue || hasCompleteReleaseSigning) {
    "Android release signing is only partially configured. Set all four " +
        "RALLYMATE_ANDROID_KEYSTORE_* / RALLYMATE_ANDROID_KEY_* variables."
}

android {
    namespace = "com.rallymate.rallymate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must match the Wear OS app applicationId for Wearable Data Layer sync.
        applicationId = "com.rallymate.rallymate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect client 1.1.0 requires API 26+. Keep this explicit so
        // Play/App QA does not ship an APK with a manifest override.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasCompleteReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigningValues.getValue("RALLYMATE_ANDROID_KEYSTORE_PATH")!!)
                storePassword =
                    releaseSigningValues.getValue("RALLYMATE_ANDROID_KEYSTORE_PASSWORD")
                keyAlias = releaseSigningValues.getValue("RALLYMATE_ANDROID_KEY_ALIAS")
                keyPassword = releaseSigningValues.getValue("RALLYMATE_ANDROID_KEY_PASSWORD")
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            val configuredRelease = signingConfigs.findByName("release")
            if (configuredRelease != null) {
                signingConfig = configuredRelease
            } else if (
                providers.environmentVariable("RALLYMATE_ALLOW_DEBUG_RELEASE_SIGNING")
                    .orNull == "true"
            ) {
                // Explicit local smoke-test escape hatch. CI/store builds must
                // never set this value.
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
    implementation("com.google.firebase:firebase-messaging")
    // Data Layer per sync con l'app Wear OS (wear/wearos).
    implementation("com.google.android.gms:play-services-wearable:20.0.1")
    // Native local notifications + deferred reminder scheduling.
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.fragment:fragment-ktx:1.8.5")
    implementation("androidx.work:work-runtime-ktx:2.10.0")
    // Official Google Health Connect client. Keep health access phone-side.
    implementation("androidx.health.connect:connect-client:1.1.0")
    // Official Garmin Connect IQ companion SDK. Communication is relayed by
    // Garmin Connect Mobile and remains opt-in from the devices screen.
    implementation("com.garmin.connectiq:ciq-companion-app-sdk:2.4.0@aar")
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
