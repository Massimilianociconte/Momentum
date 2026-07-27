# Flutter engine/plugin keep rules are injected by the Flutter Gradle plugin.
# Dependencies with consumer rules (RevenueCat, Firebase, ML Kit, uCrop,
# Health Connect) are covered automatically. Rules below patch the gaps.

# Garmin Connect IQ companion SDK: AIDL-based IPC plus Monkeybrains value
# serialization rely on reflection; no consumer rules are shipped in the AAR.
-keep class com.garmin.android.connectiq.** { *; }
-keep class com.garmin.monkeybrains.** { *; }
-dontwarn com.garmin.**

# Flutter deferred components reference Play Core even when unused.
-dontwarn com.google.android.play.core.**

# Preserve annotations consumed by framework integrations at runtime.
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations,AnnotationDefault
