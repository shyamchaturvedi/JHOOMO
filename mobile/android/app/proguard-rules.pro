# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore model maps are accessed via toMap/fromMap (no reflection),
# but keep annotations to be safe.
-keepattributes *Annotation*
-keepattributes Signature

# mobile_scanner / ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
