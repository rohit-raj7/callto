# Keep Flutter and generated plugin registration entry points.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native method signatures that are loaded through JNI.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Agora RTC and wrappers use JNI/reflection internally.
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Keep useful metadata for reflection/serialization where used.
-keepattributes Signature,*Annotation*

# Remove verbose Android log calls in release builds.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}
