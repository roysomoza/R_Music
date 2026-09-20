# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core & Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Audio Service & Just Audio (Background playback, MediaBrowser, AudioFocus)
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-dontwarn com.ryanheise.audioservice.**
-dontwarn com.ryanheise.just_audio.**
-dontwarn com.ryanheise.audio_session.**

# Android Media & Notifications
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class android.media.audiofx.** { *; }

# App Package & Native Channels (Equalizer, MainActivity)
-keep class com.example.pure_audio.** { *; }

# Plugin Keep Rules
-keep class com.baseflow.permissionhandler.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep Attributes
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses,EnclosingMethod
