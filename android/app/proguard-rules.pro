# Flutter and plugin keep rules for R8/minified release builds.

-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications keeps its scheduled-notification classes by reflection.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-dontwarn com.dexterous.**

# flutter_downloader runs a WorkManager worker resolved by name.
-keep class vn.hunghd.flutterdownloader.** { *; }
-keep class androidx.work.** { *; }

# Firebase / Crashlytics need line numbers to symbolicate.
-keepattributes SourceFile,LineNumberTable
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Bluetooth thermal printing.
-keep class com.example.print_bluetooth_thermal.** { *; }

# Models parsed via reflection by json handling in plugins.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
