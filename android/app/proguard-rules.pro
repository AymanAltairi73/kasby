# ProGuard Rules for Kasby Android Release Build

# Flutter Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Supabase & Realtime Keep Rules
-keep class com.supabase.** { *; }
-keep class io.supabase.** { *; }
-dontwarn com.supabase.**

# Firebase & FCM Keep Rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# GetX Keep Rules
-keep class com.getx.** { *; }
-keep class get.** { *; }

# Google Play Core & Deferred Components
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# General Keep Attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
