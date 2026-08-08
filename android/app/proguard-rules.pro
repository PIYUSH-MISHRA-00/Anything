# R8 / ProGuard rules — IS-P01
#
# Flutter's own engine rules ship with the Gradle plugin; these cover the
# plugin set this project actually depends on. Each rule names why it exists,
# so a future reader can delete one when the dependency goes away rather than
# keeping it forever out of caution.

# ── Flutter engine ─────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── sqflite ────────────────────────────────────────────────────────────────
# The canonical Experience repository is SQLite-backed. The plugin reaches
# native code by name.
-keep class com.tekartik.sqflite.** { *; }

# ── flutter_secure_storage ─────────────────────────────────────────────────
# Backs CredentialVault (AI provider keys). Uses the AndroidX security
# library, which relies on reflection over Tink.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }

# ── speech_to_text / record ────────────────────────────────────────────────
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.llfbandit.record.** { *; }

# ── webview_flutter ────────────────────────────────────────────────────────
-keep class android.webkit.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ── Play Core / deferred components ────────────────────────────────────────
# MEASURED, NOT PRECAUTIONARY. Enabling R8 in IS-P01 failed the build with
# "Missing class com.google.android.play.core.splitcompat.SplitCompatApplication
# (referenced from FlutterPlayStoreSplitApplication)" and nine sibling errors.
#
# Flutter's engine references Play Core unconditionally for deferred component
# loading; this app does not use deferred components, so the library is not on
# the classpath and the references are genuinely unreachable. Warning about
# them is correct of R8 and wrong for this app.
#
# Do NOT convert these to -keep: that would require adding the Play Core
# dependency for code no path reaches.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication

# ── StAX (via Apache Tika, reached transitively through content extraction) ─
# Same measurement: "Missing class javax.xml.stream.XMLStreamException
# (referenced from org.apache.tika.utils.XMLReaderUtils)". StAX is a Java SE
# API that does not exist on Android; Tika guards its use at runtime.
-dontwarn javax.xml.stream.**
-dontwarn org.apache.tika.**

# ── Kotlin / coroutines metadata ───────────────────────────────────────────
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ── Keep line numbers for readable release stack traces ────────────────────
# Anything reports uncaught errors through its own zone guard (main.dart).
# Without these, every release crash report is unattributable.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
