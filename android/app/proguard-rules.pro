# Add project specific ProGuard rules here.

-keep class com.alafif.newform.** { *; }
-keep class * extends io.flutter.embedding.android.FlutterActivity
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
