# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / GoTrue / PostgREST (uses Gson/reflection)
-keep class io.supabase.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# Kotlin serialization
-keepclassmembers class kotlinx.serialization.** { *; }
-keep class kotlinx.serialization.** { *; }

# Hive
-keep class com.crazecoder.openfile.** { *; }
-keep class hive.** { *; }

# OkHttp / networking
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# General Android
-keep class androidx.** { *; }
-keep class com.google.android.** { *; }
