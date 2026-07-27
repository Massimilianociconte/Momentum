plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Same keystore as the phone app: Data Layer pairing requires that both
// APKs share applicationId AND signing certificate. All-or-nothing check
// mirrors apps/rallymate/android/app/build.gradle.kts.
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
    namespace = "com.rallymate.wear"
    compileSdk = 35

    defaultConfig {
        // MUST match the phone app applicationId (Data Layer pairing) and be
        // signed with the same certificate.
        applicationId = "com.rallymate.rallymate"
        minSdk = 30 // Wear OS 3+
        targetSdk = 35
        // Keep versionName in sync with the phone app (pubspec.yaml). Play
        // requires a versionCode distinct from the phone AAB: wear uses the
        // 1xxx range so both artifacts can live in the same release.
        versionCode = 1001
        versionName = "0.1.0"
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfigs.findByName("release")?.let { signingConfig = it }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation(platform("androidx.compose:compose-bom:2024.09.03"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")

    // Compose for Wear OS
    implementation("androidx.wear:wear:1.4.0")
    implementation("androidx.wear:wear-ongoing:1.1.0")
    implementation("androidx.wear.compose:compose-material:1.4.0")
    implementation("androidx.wear.compose:compose-foundation:1.4.0")

    // Native workout session on Wear OS.
    implementation("androidx.health:health-services-client:1.1.0-rc02")

    // Data Layer (sync col telefono)
    implementation("com.google.android.gms:play-services-wearable:20.0.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.8.1")

    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.6")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
